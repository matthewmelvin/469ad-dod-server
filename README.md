On the lan...

```
docker run -d -it -v /tmp:/tmp \
	-e RCONPASS=<password> \
	-e LANFLAG=1 \
        -e EXTIP=<lanip> \
	-e SRVID=<ident> \
	--restart unless-stopped \
	--net=host \
	--name dod-server \
	dod-server:latest
```

EXTIP is the IP of the host docker is running on. 

This is the used for lighthttpd to provide asset downloads.

On the net...

```
docker run -d -it -v /tmp:/tmp \
	-e RCONPASS=<password> \
        -e LANFLAG=0 \
	-e LCLIP=<lanip> \
	-e SRVID=<ident> \
        -e USERTOK=<token> \
        --restart unless-stopped \
	--net=host \
        --name dod-server \
        dod-server:latest
```

USERTOK is a steam token to register the server with.

LCLIP is the IP of the host docker is running on.

This is used by hlxstats to find the log server.

SVRID is a short server to identify the server instance.

See: https://steamcommunity.com/dev/managegameservers

Additional...

The `maps/` directory is excluded from git because `*.bsp` files are too big.

See comments in the Dockerfile for download locations of maps and other resources.
