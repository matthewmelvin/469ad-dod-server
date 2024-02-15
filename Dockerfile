FROM ubuntu:22.04

# pre-configure steam for non-interactive install
RUN echo steam steam/question select "I AGREE" | debconf-set-selections \
  && echo steam steam/license note '' | debconf-set-selections

# install steamcmd and a few other bits and pieces
ARG DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 \
  && apt-get update -y \
  && apt-get install -y --no-install-recommends \
    ca-certificates locales unzip sudo \
    libcurl4:i386 libncurses5:i386 libsdl2-2.0-0:i386 \
    steamcmd \
    vim less \
  && rm -rf /var/lib/apt/lists/* \
  && ln -s /usr/games/steamcmd /usr/bin/steamcmd

# configure unicode  / locale
RUN locale-gen en_US.UTF-8
ENV LANG 'en_US.UTF-8'
ENV LANGUAGE 'en_US:en'

# create a non-root user to use steam
ENV USER steam
ENV HOME /home/$USER
RUN useradd -r -m -c "Steam User" $USER -s /bin/bash \
  && printf "Defaults:%s !requiretty\n" $USER > /etc/sudoers.d/$USER \
  && printf "%s ALL=(ALL) NOPASSWD: ALL\n" $USER >> /etc/sudoers.d/$USER 
USER $USER

# do some initial setup up the steam client
RUN chdir $HOME \
  && mkdir .steam \
  && steamcmd +quit \
  && ln -s $HOME/.local/share/Steam/steamcmd/linux32 $HOME/.steam/sdk32 \
  && ln -s $HOME/.local/share/Steam/steamcmd/linux64 $HOME/.steam/sdk64 \
  && ln -s $HOME/.steam/sdk32/steamclient.so $HOME/.steam/sdk32/steamservice.so \
  && ln -s $HOME/.steam/sdk64/steamclient.so $HOME/.steam/sdk64/steamservice.so

# get steam to download and install the game
RUN chdir $HOME \
  && mkdir dod-server \
  && steamcmd +force_install_dir $HOME/dod-server +login anonymous +app_update 232290 +quit

# metamod - https://wiki.alliedmods.net/Installing_Metamod:Source
# rcbots - https://github.com/APGRoboCop/rcbot2
# sourcemod - https://wiki.alliedmods.net/Installing_sourcemod
# dod:s damage report - https://forums.alliedmods.net/showthread.php?p=1765621
# delay hibertnate - https://forums.alliedmods.net/showthread.php?p=2740332
# extra maps - https://www.dodbits.com/dods/index.php/downloads/category/38-rcbot2-waypoints
#   RCBot2_75_custom_dods_maps - https://www.dodbits.com/dods/index.php/downloads/summary/43-rcbot2-installation-packages/198-rcbot2-map-pack-1
#   RCBot2_map_pack_2 - https://www.dodbits.com/dods/index.php/downloads/summary/43-rcbot2-installation-packages/199-rcbot2-map-pack-2
# extra waypoints - https://www.dodbits.com/dods/index.php/downloads/category/38-rcbot2-waypoints
#   september_2023_rcbot2_all_waypoints_pack - https://www.dodbits.com/dods/index.php/downloads/category/38-rcbot2-waypoints
COPY config/ /tmp/config
COPY addons/ /tmp/addons
COPY maps/ /tmp/maps
COPY waypoints/ /tmp/waypoints
RUN chdir $HOME/dod-server/dod \
  && find /tmp \
  && tar -xzvf /tmp/addons/mmsource-1.11.0-git1153-linux.tar.gz \
  && rm -v addons/metamod_x64.vdf \
  && unzip /tmp/addons/rcbot2.zip \
  && tar -xzvf /tmp/addons/sourcemod-1.11.0-git6954-linux.tar.gz \
  && unzip /tmp/addons/delayhibernate.zip \
  && mv -v addons/sourcemod/plugins/*.smx addons/sourcemod/plugins/disabled/ \
  && cp -v /tmp/addons/dod_damage_report.smx addons/sourcemod/plugins/ \
  && cp -v /tmp/addons/dod_damage_report.phrases.txt addons/sourcemod/translations/ \
  && cp -v /tmp/maps/*.bsp maps/ \
  && cp -v /tmp/waypoints/*.rcw addons/rcbot2/waypoints/dod/ \
  && cp -v /tmp/config/server.cfg cfg/ \
  && cp -v /tmp/config/mapcycle.txt cfg/ \
  && cp -v /tmp/config/rcbot2.ini addons/rcbot2/config/config.ini \
  && cp -v /tmp/config/startup.sh ../ \
  && chmod 755 ../startup.sh \
  && sudo rm -rvf /tmp/config /tmp/addons /tmp/maps /tmp/waypoints

# use a script so command can be edited without a rebuild
WORKDIR $HOME/dod-server
ENTRYPOINT ["/bin/bash"]
CMD ["./startup.sh"]
