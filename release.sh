#!/bin/bash

ssh www@a11.xd.cn "cd /home/www/sites/uri.xdcdn.net && git pull && touch tmp/restart.txt"

if [ "x$1" != "xok" ]; then
    exit 0
fi

ssh www@20v001.xd.cn "cd /home/www/sites/uri.xdcdn.net && git pull && touch tmp/restart.txt"
ssh -p 22281 www@kti.xd.com "cd /home/www/sites/uri.xdcdn.net && git pull && touch tmp/restart"; done
