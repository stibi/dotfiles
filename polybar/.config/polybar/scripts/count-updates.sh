#!/bin/sh

if [ -s ~/.countupdates.count ] ; then
    updates=$(cat ~/.countupdates.count)
else
    updates=0
fi

if [ "$updates" -gt 0 ]; then
    echo -e "\U1f4e6 #$updates"
else
    echo ""
fi

