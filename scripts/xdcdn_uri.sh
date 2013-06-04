#!/bin/bash

if test "x$1" == "x"; then
    echo "Usage: ./$0 [sxd|sgf|ktk|jsk|...]"
    exit 1
fi

LANG=en_US.UTF-8
HOME=/home/www
GITB="/usr/bin/git"
BGIT="uri-$1.git"
RARGS="-av --timeout=600 --delete-before"

cd /home/www/sites/$BGIT || exit 1

while true; do
    nowt=`date '+[%Y-%m-%d %H:%M:%S]'`
    cd /home/www/sites/$BGIT && echo $nowt && git fetch --all && git fetch --tags && ( if test "x$2" == "xmem"; then rsync $RARGS ./ /mnt/uri.xdcdn.net/$BGIT/; fi )
    echo "$nowt sleep 10 .........." && sleep 10
done
