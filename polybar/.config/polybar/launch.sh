#!/bin/sh

# Inspiration: https://github.com/polybar/polybar/issues/763
# Cil je vyresit polybar na vicero monitorech, pokud je jich vicero pouzivano.
# Pravidlo je, ze taskbar a vsechny ty moduly se drzi na primarnim monitoru.
# Na externim neni nic krome indikatoru virtualni plochy
# Mam definovane dva polybary v konfiguraci, "primary" a "external"

# killall -q polybar

# TODO soubor s logem
# TODO jak prestehovat automaticky existujici plochy kdyz se zmeni primarni monitor?

# Wait until the processes have been shut down
# while pgrep -u $UID -x polybar > /dev/null; do sleep 1; done

# primary monitor, tam bude taskbar a ostatni kokotinky
primary_monitor=$(xrandr -q | grep -w "primary" | awk '{print $1}')

# tenhle xrandr je na prd, protoze vypise fakt vsechny pripojene monitory, kdy ne vsechny jsou ale v systemu zapnute 
# = jsem na dockine, chci jen externi monitor, ale ten interni tam furt je, zeano
#outputs=$(xrandr --query | grep " connected" | cut -d" " -f1)
outputs=$(polybar --list-monitors | cut -d":" -f1)
# set -- $outputs
# tray_output=$1

# true if no polybar is running, no pid is returned from pgrep, meaning polybar have to started
if [ -z "$(pgrep -x polybar)" ]; then
    for m in $outputs; do
        if [ $m == ${primary_monitor} ] 
        then
            # echo "primarni=$m"		
            PRIMARY_MONITOR=$m polybar --reload primary &	
        else
            EXTERNAL_MONITOR=$m polybar --reload external &
        fi
    done
# and in case polybar is actually running, let's restart it
# akorat by bylo zahodno zminit, ze tenhleten restart neumi treba prstehovat taskbar a spol na novy primarni monitor, je treba kill
else
    polybar-msg cmd restart
fi
