#!/bin/bash

cd "$(dirname "$0")"

sudo /etc/init.d/lighttpd start
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

if [ "$lan" -eq "1" ]; then
	desc="Mloe's local DoD:S server"
else
	desc="469AD's ephemeral DoD:S server"
fi

map=$(grep ^dod_ dod/cfg/mapcycle.txt | head -1 | tee /dev/stderr)


: > dod/cfg/startup.txt
echo "sv_downloadurl \"http://$extip:$port/\"" >> dod/cfg/startup.txt
echo "hostname \"$desc\"" >> dod/cfg/startup.txt

./srcds_run -game dod \
	-port 27015 +ip 0.0.0.0 \
	-strictportbind +sv_lan $lan \
	${tok:++sv_setsteamaccount $tok} \
	+map $map +exec startup.txt
