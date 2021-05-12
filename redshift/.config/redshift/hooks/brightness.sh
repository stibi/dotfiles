#!/bin/sh

# Set brightness via xbrightness when redshift status changes

# Set brightness values for each status.
# Range from 1 to 100 is valid
brightness_day=100
brightness_transition=80
brightness_night=65

if [ "$1" = period-changed ]; then
	case $3 in
		night)
			light -S $brightness_night
			;;
		transition)
			light -S $brightness_transition
			;;
		daytime)
			light -S $brightness_day
			;;
	esac
fi