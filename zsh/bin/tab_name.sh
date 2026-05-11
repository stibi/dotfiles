#!/bin/bash

# Credits to https://gist.github.com/phette23/5270658 for inspiration

# https://superuser.com/a/599156
function setTabname {
    echo -ne "\033]0;"$*"\007"
}

# set the title using above declared function and set the color of 
# current iterm tab to value based on the md5-hash of dirname
colortab() {
	CURRENT_WORKDIR_NAME_FOR_CUSTOM_TAB=$(basename $(pwd))
	setTabname ${CURRENT_WORKDIR_NAME_FOR_CUSTOM_TAB}
	CONS_HEX_COLOR_OF_WORKDIR=$(echo -n $CURRENT_WORKDIR_NAME_FOR_CUSTOM_TAB | md5 | cut -c1-6 | tr a-z A-Z)

	REDC=$(echo $CONS_HEX_COLOR_OF_WORKDIR | cut -c 1,2 | xargs -I % echo "ibase=16; %" | bc)
	GREENC=$(echo $CONS_HEX_COLOR_OF_WORKDIR | cut -c 3,4 | xargs -I % echo "ibase=16; %" | bc)
	BLUEC=$(echo $CONS_HEX_COLOR_OF_WORKDIR | cut -c 5,6 | xargs -I % echo "ibase=16; %" | bc)

	echo -ne "\033]6;1;bg;red;brightness;${REDC}\a"
	echo -ne "\033]6;1;bg;green;brightness;${GREENC}\a"
	echo -ne "\033]6;1;bg;blue;brightness;${BLUEC}\a"

    printf "New Tab color: \x1b[38;2;${REDC};${GREENC};${BLUEC}m■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■\x1b[0m\n"
}

