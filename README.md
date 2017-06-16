# Pomodoro plugin for Xfce4 panel

This bash script uses `xfce4-genmon-plugin` and `libnotify` to create a simple
Pomodoro timer for Xfce4 panel. After `xfce4-genmon-plugin` is added to the
panel - it should point to the `pomodoro.sh` script and period should be set to
some small value (e.g. 1 second).

To configure parameters please go to `pomodoro.sh` and configure:

* `size` - icon size in pixels
* `ptime` - time for the pomodoro cycle (in minutes)
* `notify_time` - time for notifcation to hang (in seconds)

The icons are stolen form [here](http://www.flickr.com/photos/bcolbow/3842129453/).

Happy Pomodoro !!
