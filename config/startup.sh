#!/bin/bash

cd "$(dirname "$0")" || exit 1

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
	desc="469AD's ephemeral DoD:S server${SRVID:+ ($SRVID)}"
fi

if [ -s dod/cfg/lastmap.txt ] && find dod/cfg/lastmap.txt -mmin -20 | grep -q .; then
	map=$(grep ^dod_ dod/cfg/lastmap.txt | head -1 | tee /dev/stderr)
fi

if [ -z "$map" ]; then
	map=$(grep ^dod_ dod/cfg/mapcycle.txt | shuf -n 1 | tee /dev/stderr)
fi

: > dod/cfg/startup.txt
echo "sv_downloadurl \"http://$extip:$port/\"" >> dod/cfg/startup.txt
echo "hostname \"$desc\"" >> dod/cfg/startup.txt

# For whatever reason, cpu does not go idle when hibernating even after the bots
# are all kicked out.  But cpu will idle on newly started server until the first
# user comes along.  So when the server tries to hibernate after that, force the
# container to restart (assumes restart=unless-stopped set). Track last map seen
# so the mapcycle isn't constantly being sent back to the beginning.
: > dod/console.log
(tail -f dod/console.log | while read -r line; do
	if [ "$used" != "1" ] && echo "$line" | grep -q "^Client.*connected"; then
		echo "The first client has connected..."
		used=1
		continue
        fi
	last=$(echo "$line" | grep 'Mapchange' | rev | awk '{print $2}' | rev)
	if [ -n "$last" ]; then
		echo "Setting last seen map to $last ..."
		echo "$last" > dod/cfg/lastmap.txt
		continue
	fi
	if echo "$line" | grep -q "Server is hibernating"; then
		if [ "$used" != "1" ]; then
			echo "Server not used, letting hibernate..."
			continue
		fi
		echo "Shutting down container via kill..."
		ps auxwww | awk '/[s]rcds_run/{print $2}' | xargs -r kill
		exit
	fi
done) &

./srcds_run -condebug -game dod \
	-port 27015 +ip 0.0.0.0 \
	-strictportbind +sv_lan $lan \
	${tok:++sv_setsteamaccount $tok} \
	+map "$map" +exec startup.txt
