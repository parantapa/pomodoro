#!/bin/bash

# This is a simple script for pomodoro timer.
# This is intended to be used with xfce4-genmon-plugin.

size=24		# Icon size in pixels
pomodoro_time=25	# Time for the pomodoro cycle (in minutes)
short_break_time=5	# Time for the short break cycle (in minutes)
long_break_time=15	# Time for the long break cycle (in minutes)
cycles_between_long_breaks=4 # How many cycles should we do before long break
notify_time=5	# Time for notification to hang (in seconds)

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

savedtime="$DIR/savedtime"
savedmode="$DIR/savedmode"
savedcyclecount="$DIR/savedcyclecount"
lock="$DIR/lock"

pomodoro_cycle=$(( pomodoro_time * 60 ))
short_break_cycle=$(( short_break_time * 60 ))
long_break_cycle=$(( long_break_time * 60 ))
notify_time=$(( notify_time * 1000 ))
summary="Pomodoro"
startmsg="Pomodoro started, you have $pomodoro_time minutes left"
endmsg_shortbreak="Pomodoro ended, stop the work and take short break"
endmsg_longbreak="Pomodoro ended, stop the work and take long break"
killmsg="Pomodoro stopped, restart when you are ready"

function xnotify () {
	notify-send -t $notify_time -i "$DIR/icons/running.png" "$summary" "$1"
}

function terminate_pomodoro () {
	xnotify "$killmsg"
	echo "" > "$savedtime"
	echo "idle" > "$savedmode"
	echo "" > "$savedcyclecount"
}

( flock -x 200


mode=$( cat "$savedmode" 2> /dev/null )
if [ -z "$mode" ] ; then
	mode="idle"
fi

current_time=$( date +%s )

if [ "$1" == "-n" ] ; then
	if [ "$mode" == "idle" ] ; then
		xnotify "$startmsg"
		echo $current_time > "$savedtime"
		echo "pomodoro" > "$savedmode"
		echo "0" > "$savedcyclecount"
	else
		terminate_pomodoro

	fi
else
	# periodic check, and redrawing

	echo "<click>$DIR/pomodoro.sh -n</click>"

	if [ $mode == "idle" ] ; then
		echo "<img>$DIR/icons/stopped$size.png</img>"
		echo "<tool>No Pomodoro Running</tool>"

	else
		# timer running

		cycle_start_time=$( cat "$savedtime" 2> /dev/null )
		saved_cycle_count=$( cat "$savedcyclecount" 2> /dev/null )

		if [ -z "$cycle_start_time" ] ; then
			cycle_start_time=0
		fi

		if [ -z "$saved_cycle_count" ] ; then
			saved_cycle_count=0
		fi

		cycle_time=0
		if [ "$mode" == "pomodoro" ] ; then
			cycle_time=$pomodoro_cycle
		elif [ "$mode" == "shortbreak" ] ; then
			cycle_time=$short_break_cycle
		elif [ "$mode" == "longbreak" ]; then
			cycle_time=$long_break_cycle
		fi

		remaining_time=$(( cycle_time + cycle_start_time - current_time))

		msg=$startmsg
		if [ $remaining_time -lt 0 ] ; then
			# If remaining_time is is below zero for more that short break cycle,
			# that makes pomodoro invalid.
			# This, for example, can occure when computer was turned off.
			# In such case terminate pomodoro and exit.
			invalid_pomodoro_time_margin=$((-short_break_cycle))
			if [ $remaining_time -lt $invalid_pomodoro_time_margin ] ; then
				terminate_pomodoro
				exit 1
			fi

			if [ $mode == "pomodoro" ] ; then
				cycle_count=$(($saved_cycle_count + 1))
				cycle_mod=$(($cycle_count % $cycles_between_long_breaks))
				newmode="shortbreak"
				msg=$endmsg_shortbreak
				if [ $cycle_mod -eq 0 ] ; then
				  newmode="longbreak"
				  msg=$endmsg_longbreak
				fi
				echo "$newmode" > $savedmode
				echo "$cycle_count" > $savedcyclecount

			else
				echo "pomodoro" > $savedmode
				msg=$startmsg

			fi

			aplay "$DIR/cow.wav"
			xnotify "$msg"
			zenity --info --text="$msg"
			echo "$current_time" > "$savedtime"

		else
			display_mode="Work"
			if [ $mode == "shortbreak" ] ; then
				display_mode="Short break"
			elif [ $mode == "longbreak" ] ; then
				display_mode="Long break"
			fi

		fi

		echo "<img>$DIR/icons/running$size.png</img>"
		echo "<tool>$display_mode: You have $(( remaining_time / 60 )):$(( remaining_time % 60 )) min left [#$saved_cycle_count]</tool>"
	fi
fi

) 200> "$lock"

