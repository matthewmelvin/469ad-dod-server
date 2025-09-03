FROM ubuntu:24.04

ENV USER steam
ENV HOME /home/$USER

ARG DEBIAN_FRONTEND=noninteractive
RUN echo steam steam/question select "I AGREE" | debconf-set-selections \
  && echo steam steam/license note '' | debconf-set-selections \
  && apt-get update -y \
  && apt-get install -y --no-install-recommends \
    ca-certificates locales \
    unzip unrar sudo curl \
    vim-tiny less \
    lighttpd \
    software-properties-common \
  && ln -s vi /usr/bin/vim \
  && add-apt-repository multiverse \
  && dpkg --add-architecture i386 \
  && echo "deb http://security.ubuntu.com/ubuntu focal-security main universe" > /etc/apt/sources.list.d/ubuntu-focal-sources.list \
  && apt-get update -y \
  && apt-get install -y --no-install-recommends \
    libncurses5:i386 libsdl2-2.0-0:i386 libcurl4t64:i386 \
    steamcmd \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && locale-gen en_US.UTF-8 \
  && ln -s /usr/games/steamcmd /usr/bin/steamcmd \
  && sed -i -e "s#/var/www/html#$HOME/dod-server/dod/maps#" /etc/lighttpd/lighttpd.conf \
  && sed -i -e 's/^\(server.port[[:space:]]*=[[:space:]]*\).*/\18082/' /etc/lighttpd/lighttpd.conf \
  && useradd -r -m -c "Steam User" $USER -s /bin/bash \
  && usermod www-data -G $USER \
  && printf "Defaults:%s !requiretty\n" $USER > /etc/sudoers.d/$USER \
  && printf "%s ALL=(ALL) NOPASSWD: ALL\n" $USER >> /etc/sudoers.d/$USER \
  && su - $USER -c "mkdir .steam \
    && steamcmd +quit \
    && ln -s $HOME/.local/share/Steam/steamcmd/linux32 $HOME/.steam/sdk32 \
    && ln -s $HOME/.local/share/Steam/steamcmd/linux64 $HOME/.steam/sdk64 \
    && ln -s $HOME/.steam/sdk32/steamclient.so $HOME/.steam/sdk32/steamservice.so \
    && ln -s $HOME/.steam/sdk64/steamclient.so $HOME/.steam/sdk64/steamservice.so \
    && mkdir dod-server \
    && steamcmd +set_download_throttle 75000 +force_install_dir $HOME/dod-server +login anonymous +app_update 232290 +quit"

COPY config/ /tmp/config
COPY addons/ /tmp/addons
COPY waypoints/ /tmp/waypoints

RUN su - $USER -c "cd $HOME/dod-server/dod \
    && find /tmp \
    && tar -xzvf /tmp/addons/mmsource-2.0.0-git1348-linux.tar.gz \
    && rm -rvf addons/metamod/bin/linux64/ \
               addons/metamod/bin/linuxsteamrt64 \
               addons/metamod_x64.vdf \
    && unzip /tmp/addons/rcbot2alpha5.zip \
    && rm -rf addons/rcbot2/waypoints/hl2mp \
              addons/rcbot2/waypoints/synergy \
              addons/rcbot2/waypoints/tf \
              addons/rcbot2/manual \
              addons/rcbot2/profiles/*ini \
    && cp -v /tmp/waypoints/*.rcw addons/rcbot2/waypoints/dod/ \
    && cp -v /tmp/addons/{rcbot.2.dods.so,RCBot2Meta_i486.so} addons/rcbot2/bin/ \
    && tar -xzvf /tmp/addons/sourcemod-1.12.0-git7196-linux.tar.gz \
    && rm -rf addons/sourcemod/bin/x64 \
              addons/sourcemod/bin/x64 \
    && mv -v addons/sourcemod/plugins/*.smx addons/sourcemod/plugins/disabled/ \
    && mv addons/sourcemod/plugins/disabled/admin-flatfile.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/adminhelp.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/adminmenu.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/basebans.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/basecommands.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/basetriggers.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/clientprefs.smx addons/sourcemod/plugins/ \
    && unzip /tmp/addons/delayhibernate.zip \
    && unzip /tmp/addons/dodsfixchangelevel_win_linux_24022025.zip \
    && cp -v /tmp/addons/dod_botfriendlyfire.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dod_dynamicbotlimit.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dod_newteambalancer.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dod_stuckbotkiller.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dod_detonatenades.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/jagdswitcher.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/hlstatsx.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/superlogs-dods.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/sm_dod_medic.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/sm_dod_pistols.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dod_fireworks.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dodmedic.phrases.txt addons/sourcemod/translations/ \
    && cp -v /tmp/addons/dod_damage_report.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dod_damage_report.phrases.txt addons/sourcemod/translations/ \
    && cp -v /tmp/config/motd.txt cfg/ \
    && cp -v /tmp/config/motd_text.txt cfg/ \
    && cp -v /tmp/config/server.cfg cfg/ \
    && cp -v /tmp/config/mapcycle.txt cfg/ \
    && cp -v /tmp/config/rcbot2.ini addons/rcbot2/config/config.ini \
    && cp -v /tmp/config/hookinfo.ini addons/rcbot2/config/hookinfo.ini \
    && cp -v /tmp/config/bot_quota.ini addons/rcbot2/config/ \
    && cp -v /tmp/config/profiles/*.ini addons/rcbot2/profiles/ \
    && cp -v /tmp/config/admins_simple.ini addons/sourcemod/configs/ \
    && cp -v /tmp/config/startup.sh ../ \
    && chmod 755 ../startup.sh \
    && mkdir maps/graphs \
    && mkdir -p maps/sound/bandage \
    && cp -v /tmp/addons/bandage.mp3 maps/sound/bandage/ \
    && ln -s . maps/maps" \
  && rm -rf /tmp/* /var/tmp/*

ENV LANG 'en_US.UTF-8'
ENV LANGUAGE 'en_US:en'
USER $USER
WORKDIR $HOME/dod-server

# use a script so command can be edited without a rebuild
ENTRYPOINT ["/bin/bash"]
CMD ["./startup.sh"]
