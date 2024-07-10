On the lan...

```
docker run -d -it -v /tmp:/tmp \
	-e LANFLAG=1 \
        -e EXTIP=<lanip> \
	-p 8082:80 -p 27000-27015:27000-27015/udp -p 27015:27015 \
	--restart unless-stopped \
	--name dod-server \
	dod-server:latest
```

EXTIP is the IP of the host docker is running on. 

This is the used for lighthttpd to provide asset downloads.

On the net...

```
docker run -d -it -v /tmp:/tmp \
        -e LANFLAG=0 \
        -e USERTOK=<token> \
        -p 8082:80 -p 27000-27015:27000-27015/udp -p 27015:27015 \
        --name dod-server \
        --restart unless-stopped \
        dod-server:latest
```

USERTOK is a steam token to register the server with.

See: https://steamcommunity.com/dev/managegameservers

Additional...

The `maps/` directory is excluded from git because `*.bsp` files are too big.

See comments in the Dockerfile for download locations of maps and other resources.
