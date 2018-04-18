#!/bin/bash

# This is a simple script for pomodoro timer.
# This is intended to be used with xfce4-genmon-plugin.

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function xnotify () {
	notify-send -t $notify_time -i "$DIR/icons/running.png" "$summary" "$1"
}

function terminate_pomodoro () {
	xnotify "$killmsg"
	echo "" > "$savedtime"
	echo "idle" > "$savedmode"
	echo "" > "$savedcyclecount"
}

function render_status () {
	mode=$1
	remaining_time=$2
	saved_cycle_count=$3

	display_mode="Work"
	display_icon="running"
	if [ $mode == "shortbreak" ] ; then
		display_mode="Short break"
		display_icon="stopped"
	elif [ $mode == "longbreak" ] ; then
		display_mode="Long break"
		display_icon="stopped"
	fi

	# when pomodoro is off or break is active stop icon is displayed,
	# but user can intuitively and immidiatelly notice the difference,
	# because if it is break remaining time is displayed.
	remaining_time_display=$(printf "%02d:%02d" $(( remaining_time / 60 )) $(( remaining_time % 60 )))
	echo "<click>$DIR/pomodoro.sh -n --pomodoro_time $pomodoro_time</click>"
	echo "<txt>$remaining_time_display</txt>"
	echo "<img>$DIR/icons/$display_icon$size.png</img>"
	echo "<tool>$display_mode: You have $remaining_time_display min left [#$saved_cycle_count]</tool>"
}

sound="on"
storage="$DIR"
pomodoro_time=25	# Time for the pomodoro cycle (in minutes)
short_break_time=5	# Time for the short break cycle (in minutes)
long_break_time=15	# Time for the long break cycle (in minutes)
cycles_between_long_breaks=4 # How many cycles should we do before long break

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--click)
    click=yes
    shift # past argument
    ;;
    -t|--storage)
    storage="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--sound)
    sound="$2"
    shift # past argument
    shift # past value
    ;;
    --pomodoro_time)
    pomodoro_time="$2"
    shift # past argument
    shift # past value
    ;;
    --short_break_time)
    short_break_time="$2"
    shift # past argument
    shift # past value
    ;;
    --long_break_time)
    long_break_time="$2"
    shift # past argument
    shift # past value
    ;;
    --cycles_between_long_breaks)
    cycles_between_long_breaks="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    # ignore unknown argument
    shift # past argument
    ;;
esac
done

mkdir -p "$storage"
savedtime="$storage/savedtime"
savedmode="$storage/savedmode"
savedcyclecount="$storage/savedcyclecount"
lock="$storage/lock"

size=24		# Icon size in pixels
notify_time=5	# Time for notification to hang (in seconds)

pomodoro_cycle=$(( pomodoro_time * 60 ))
short_break_cycle=$(( short_break_time * 60 ))
long_break_cycle=$(( long_break_time * 60 ))
notify_time=$(( notify_time * 1000 ))
summary="Pomodoro"
startmsg="Pomodoro started, you have $pomodoro_time minutes left"
endmsg_shortbreak="Pomodoro ended, stop the work and take short break"
endmsg_longbreak="Pomodoro ended, stop the work and take long break"
killmsg="Pomodoro stopped, restart when you are ready"

( flock -x 200

mode=$( cat "$savedmode" 2> /dev/null )
if [ -z "$mode" ] ; then
	mode="idle"
fi

current_time=$( date +%s )

if [ "$click" == "yes" ] ; then
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

	if [ $mode == "idle" ] ; then
		echo "<click>$DIR/pomodoro.sh -n --pomodoro_time $pomodoro_time</click>"
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
		if [ $remaining_time -le 0 ] ; then
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
				new_remaining_time=$short_break_cycle
				new_mode="shortbreak"
				msg=$endmsg_shortbreak
				if [ $cycle_mod -eq 0 ] ; then
				  new_mode="longbreak"
				  msg=$endmsg_longbreak
					new_remaining_time=$long_break_cycle
				fi
				echo "$new_mode" > $savedmode
				echo "$cycle_count" > $savedcyclecount
				render_status $new_mode $new_remaining_time $cycle_count

			else
				echo "pomodoro" > $savedmode
				msg=$startmsg
				render_status "pomodoro" $pomodoro_cycle $saved_cycle_count

			fi

                        if [ "$sound" == "on" ] ; then
                            aplay "$DIR/cow.wav"
                        fi
			xnotify "$msg"
			zenity --info --text="$msg"
			echo "$current_time" > "$savedtime"

		else
			render_status $mode $remaining_time $saved_cycle_count

		fi

	fi
fi

) 200> "$lock"
