FROM ubuntu:24.04

ENV USER steam
ENV HOME /home/$USER

# metamod - https://github.com/alliedmodders/metamod-source
# rcbots - https://github.com/APGRoboCop/rcbot2
# sourcemod - https://github.com/alliedmodders/sourcemod
# dod:s damage report - https://forums.alliedmods.net/showthread.php?p=1765621
# dod:s fireworks  - https://forums.alliedmods.net/showthread.php?p=740274
# delay hibertnate - https://forums.alliedmods.net/showthread.php?p=2740332
# team balance - https://forums.alliedmods.net/showpost.php?p=775579&postcount=34
# extra maps - https://www.dodbits.com/dods/index.php/downloads/category/38-rcbot2-waypoints
#   RCBot2_75_custom_dods_maps - https://www.dodbits.com/dods/index.php/downloads/summary/43-rcbot2-installation-packages/198-rcbot2-map-pack-1
#   RCBot2_map_pack_2 - https://www.dodbits.com/dods/index.php/downloads/summary/43-rcbot2-installation-packages/199-rcbot2-map-pack-2
# extra waypoints - https://www.dodbits.com/dods/index.php/downloads/category/38-rcbot2-waypoints
#   september_2023_rcbot2_all_waypoints_pack - https://www.dodbits.com/dods/index.php/downloads/category/38-rcbot2-waypoints
COPY config/ /tmp/config
COPY addons/ /tmp/addons
COPY maps/ /tmp/maps
COPY waypoints/ /tmp/waypoints

# mush everything together into one run layer
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
    steamcmd \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && locale-gen en_US.UTF-8 \
  && ln -s /usr/games/steamcmd /usr/bin/steamcmd \
  && sed -i -e "s#/var/www/html#$HOME/dod-server/dod/maps#" /etc/lighttpd/lighttpd.conf \
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
    && steamcmd +set_download_throttle 75000 +force_install_dir $HOME/dod-server +login anonymous +app_update 232290 +quit \
    && cd $HOME/dod-server/dod \
    && find /tmp \
    && tar -xzvf /tmp/addons/mmsource-2.0.0-git1334-linux.tar.gz \
    && unzip /tmp/addons/rcbot2.zip \
    && tar -xzvf /tmp/addons/sourcemod-1.13.0-git7219-linux.tar.gz \
    && mv -v addons/sourcemod/plugins/*.smx addons/sourcemod/plugins/disabled/ \
    && mv addons/sourcemod/plugins/disabled/admin-flatfile.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/adminhelp.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/adminmenu.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/basebans.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/basecommands.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/basetriggers.smx addons/sourcemod/plugins/ \
    && mv addons/sourcemod/plugins/disabled/clientprefs.smx addons/sourcemod/plugins/ \
    && unzip /tmp/addons/delayhibernate.zip \
    && cp -v /tmp/addons/dodsbalancer.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/sm_dod_medic.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dod_fireworks.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dodmedic.phrases.txt addons/sourcemod/translations/ \
    && cp -v /tmp/addons/dod_damage_report.smx addons/sourcemod/plugins/ \
    && cp -v /tmp/addons/dod_damage_report.phrases.txt addons/sourcemod/translations/ \
    && cp -v /tmp/maps/*.bsp maps/ \
    && cd ../ && unrar x /tmp/addons/dod_strand.rar && cd dod/ \
    && cp -v /tmp/waypoints/*.rcw addons/rcbot2/waypoints/dod/ \
    && cp -v /tmp/config/motd.txt cfg/ \
    && cp -v /tmp/config/motd_text.txt cfg/ \
    && cp -v /tmp/config/server.cfg cfg/ \
    && cp -v /tmp/config/mapcycle.txt cfg/ \
    && cp -v /tmp/config/rcbot2.ini addons/rcbot2/config/config.ini \
    && cp -v /tmp/config/hookinfo.ini addons/rcbot2/config/hookinfo.ini \
    && cp -v /tmp/config/bot_quota.ini addons/rcbot2/config/ \
    && rm -rvf addons/rcbot2/waypoints/hl2mp \
    && rm -rvf addons/rcbot2/waypoints/synergy \
    && rm -rvf addons/rcbot2/waypoints/tf \
    && rm -v addons/rcbot2/profiles/*ini \
    && cp -v /tmp/config/profiles/*.ini addons/rcbot2/profiles/ \
    && cp -v /tmp/config/admins_simple.ini addons/sourcemod/configs/ \
    && cp -v /tmp/config/startup.sh ../ \
    && chmod 755 ../startup.sh \
    && mkdir maps/graphs \
    && ln -s . maps/maps" \
  && rm -rf /tmp/* /var/tmp/*

ENV LANG 'en_US.UTF-8'
ENV LANGUAGE 'en_US:en'
USER $USER
WORKDIR $HOME/dod-server

# use a script so command can be edited without a rebuild
ENTRYPOINT ["/bin/bash"]
CMD ["./startup.sh"]
