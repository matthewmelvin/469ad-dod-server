#!/bin/bash

cd "$(dirname "$0")"

./srcds_run -game dod +sv_lan 1 +map dod_donner
