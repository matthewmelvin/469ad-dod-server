#!/bin/bash

cd "$(dirname "$0")"

port=8082

if [ -n "$LANFLAG" ]; then
	lan="$LANFLAG"
else
	lan=1
fi

if [ -n "$EXTIP" ]; then
	extip="$EXTIP"
else
	extip="$(curl -s ident.me | tee /dev/stderr)"; echo
fi

if [ -n "$USERTOK" ]; then
	tok="$USERTOK"
else
	tok=""
fi

map=$(grep ^dod_ dod/cfg/mapcycle.txt | head -1 | tee /dev/stderr)

sudo /etc/init.d/lighttpd start

echo "sv_downloadurl \"http://$ip:$port/\"" > dod/cfg/downloadurl.txt

./srcds_run -game dod \
	-port 27015 +ip 0.0.0.0 \
	-strictportbind +sv_lan $lan \
	${tok:++sv_setsteamaccount $tok} \
	+map $map +exec downloadurl.txt
