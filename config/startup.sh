#!/bin/bash

cd "$(dirname "$0")"

ip=$(curl -s ident.me | tee /dev/stderr); echo
ip=10.1.2.58
port=8082 # docker to map to port 80

map=$(grep ^dod_ dod/cfg/mapcycle.txt | head -1 | tee /dev/stderr)

sudo /etc/init.d/lighttpd start

echo "sv_downloadurl \"http://$ip:$port/\"" > dod/cfg/downloadurl.txt

./srcds_run -game dod +sv_lan 1 +map $map +exec downloadurl.txt
