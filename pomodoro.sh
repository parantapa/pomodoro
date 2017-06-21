#!/usr/bin/env bash

# This is a simple script for pomodoro timer.
# This is intended to be used with xfce4-genmon-plugin.

size=24         # Icon size in pixels
ptime=25        # Time for the pomodoro cycle (in minutes)
notify_time=5   # Time for notifcation to hang (in seconds)

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

state="$DIR/state"
lock="$DIR/lock"

cycle=$(( ptime * 60 ))
notify_time=$(( notify_time * 1000 ))
summary="Pomodoro"
startmsg="Pomodoro started, you have $ptime minutes left"
endmsg="Pomodoro ended, stop the work and take short break"
killmsg="Pomodoro stopped, restart when you are ready"

function xnotify () {
  notify-send -t $notify_time -i "$DIR/icons/running.png" "$summary" "$1"
}

( flock -x 200

stime=$( cat "$state" 2> /dev/null )
ctime=$( date +%s )

if [ -z "$stime" ] ; then
  stime=0
fi

rtime=$(( cycle + stime - ctime))

function format_timespan () {
  duration=$1
  min=$(($duration / 60))
  sec=$(($duration % 60))
  printf "%02d:%02d" $min $sec
}

if [ "$1" == "-n" ] ; then
  if [ $stime -eq 0 ] ; then
    xnotify "$startmsg"
    echo $ctime > "$state"
    aplay "$DIR/start.wav"
  else
    xnotify "$killmsg"
    echo "" > "$state"
    aplay "$DIR/start.wav"
  fi
else
  echo "<click>$DIR/pomodoro.sh -n</click>"
  if [ $stime -eq 0 ] ; then
    echo "<img>$DIR/icons/stopped$size.png</img>"
    echo "<tool>No Pomodoro Running</tool>"
  elif [ $rtime -lt 0 ] ; then
    xnotify "$endmsg"
    zenity --info --text="$endmsg"
    echo "" > "$state"
    echo "<img>$DIR/icons/stopped$size.png</img>"
    echo "<tool>No Pomodoro Running</tool>"
    aplay "$DIR/stop.wav"
  else
    echo "<img>$DIR/icons/running$size.png</img>"
    echo "<tool>You have `format_timespan $rtime` min left</tool>"
  fi
fi
) 200> "$lock"
