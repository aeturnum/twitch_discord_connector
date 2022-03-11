#!/bin/bash

sudo rm -rf ./_build
MIX_ENV=prod mix release --overwrite
sudo setcap CAP_NET_BIND_SERVICE+eip ~/twitch_discord_connector/_build/prod/rel/twitch_discord_connector/erts-11.1.7/bin/beam.smp
sudo setcap CAP_NET_BIND_SERVICE+eip ~/twitch_discord_connector/_build/prod/rel/twitch_discord_connector/erts-11.1.7/bin/erl