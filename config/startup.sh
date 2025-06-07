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
	echo "Using external IP from envvar: \"$extip\""
else
	extip="$(curl -s ident.me)"; echo
	echo "Using external IP from api call: \"$extip\""
fi

if [ -n "$LCLIP" ]; then
	lclip="$LCLIP"
	echo "Using local IP from envvar: \"$lclip\""
else
	lclip="$extip"
	echo "Using external IP as local IP: \"$lclip\""
fi

if [ -n "$USERTOK" ]; then
	tok="$USERTOK"
	echo "Logging in using provided token..."
else
	tok=""
	echo "Running as an anonymous server..."
fi

if [ -n "$RCONPASS" ]; then
	rcon="$RCONPASS"
	echo "Using provided rcon password...."
else
	rcon="$(tr -cd 'a-zA-Z0-9' < /dev/random | head -c10)"
	echo "Using generated rcon password...."
fi

if [ "$lan" -eq "1" ]; then
	desc="Mloe's local DoD:S server${SRVID:+ ($SRVID)}"
else
	desc="469AD's ephemeral DoD:S server${SRVID:+ ($SRVID)}"
fi

# make sure any custom maps are linked
find dod/custom -name '*.bsp' | cut -f2- -d/  | while read map; do
	(cd dod/maps && [ ! -e "$(basename $map)" ] && ln -sv "../$map" .)
done

# make sure all the maps are in the mapcycle
if [ "$(wc -l < dod/cfg/mapcycle.txt)" -ne "$(ls dod/maps/*.bsp | wc -l)" ]; then
	echo "Updating map cycle file..."
	(cd dod/maps && ls *.bsp) | sed 's/.bsp$//' | shuf > dod/cfg/mapcycle.txt
fi

# shuffle the map on the first startup of the day
if find dod/cfg/mapcycle.txt -mmin 1380 | grep -q .; then
	echo "Shuffling map cycle file..."
	shuf dod/cfg/mapcycle.txt > dod/cfg/mapcycle.tmp
	mv dod/cfg/mapcycle.tmp dod/cfg/mapcycle.txt
fi

if [ -s dod/cfg/lastmap.txt ]; then
	if find dod/cfg/lastmap.txt -mmin -10 | grep -q .; then
		# start the last map over if in first 10 minutes
		map=$(grep "^[a-z0-9]" dod/cfg/lastmap.txt | head -1)
		echo "Using map from last seen file: \"$map\""
	elif find dod/cfg/lastmap.txt -mmin -20 | grep -q .; then
		# skip to next map in the list if its been a while
		map=$(grep "^[a-z0-9]" dod/cfg/lastmap.txt | head -1)
		echo "Using next map after last seen: \"$map\""
		map=$(grep -A 1 "^${map}$" dod/cfg/mapcycle.txt | grep -v "^${map}$")
		if [ -z "$map" ]; then
			map=$(grep "^[a-z0-9]" dod/cfg/mapcycle.txt | head -1)
		fi
		echo "Using next map from map cycle file: \"$map\""
	else
		# lastmap.txt is more than 20 minutes old
		echo "Ignoring last seen file as too old."
	fi
fi
	
if [ -z "$map" ] || [ ! -f "dod/maps/${map}.bsp" ]; then
	map=$(grep "^[a-z0-9]" dod/cfg/mapcycle.txt | head -1)
	echo "Using map from map cycle file: \"$map\""
fi

if [ -z "$map" ] || [ ! -f "dod/maps/${map}.bsp" ]; then
	map=$(find dod/maps/ -name '*.bsp' | shuf -n 1 | sed 's#^.*/##; s/.bsp$//')
	echo "Using map from maps directory: \"$map\""
fi

echo "$map" > dod/cfg/lastmap.txt

(
	echo "sv_downloadurl \"http://$extip:$port/\""
	echo "hostname \"$desc\""
	echo "logaddress_add $lclip:27500"
	echo "rcon_password \"$rcon\""
) > dod/cfg/startup.txt
echo "Generated startup.txt config..."
grep -H . dod/cfg/startup.txt

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
		echo "Saving last seen map to file: \"$last"\"
		echo "$last" > dod/cfg/lastmap.txt
		continue
	fi
	if echo "$line" | grep -q "Server is hibernating"; then
		if [ "$used" != "1" ]; then
			echo "Server not used, letting hibernate..."
			continue
		fi
		echo "Removing last map tracking file..."
		rm -v dod/cfg/lastmap.txt
		echo "Shutting down container via kill..."
		ps auxwww | awk '/[s]rcds_/{print $2}' | xargs -r kill
		while true; do
			echo "Waiting to die..."
			sleep 1;
		done
	fi
done) &

./srcds_run -condebug -norestart -game dod \
	-port 27015 +ip 0.0.0.0 \
	-strictportbind +sv_lan $lan \
	${tok:++sv_setsteamaccount $tok} \
	+map "$map" +exec startup.txt
