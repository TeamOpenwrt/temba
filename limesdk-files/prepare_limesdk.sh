#!/bin/bash

## work in progress (only intended to work on 18.06.1)

set -e   # causes the shell to exit if any subcommand or pipeline returns a non-zero status.
set -v

# thanks https://unix.stackexchange.com/a/52801
if [[ $(dirname $0) != . ]]; then
  echo 'ERROR: execute script in the same directory (no absolute nor relative path)'
  exit 1
fi

# src https://gitlab.com/guifi-exo/wiki/blob/master/howto/lime-sdk.md
git clone https://github.com/libremesh/lime-sdk ../../lime-sdk

cd ../../lime-sdk

# override release
cp ../temba/limesdk-files/options.conf.local .

cp ../temba/limesdk-files/feeds.conf.temba .

# cooker does not work from other link
./cooker -f

# develop environment patch
cp ../temba/limesdk-files/regdbtz18.sh snippets/
snippets/regdbtz18.sh

# get specific version of bmx6 -> src https://gitlab.com/guifi-exo/wiki/blob/master/howto/openwrt_template.md
# more https://github.com/bmx-routing/bmx6/tree/2a87b770d3f9c254e3927dc159e2f425f2e0e83a
# warning: this assumes temba git repo is named temba and it is in the same level as lime-sdk
cp ../temba/limesdk-files/bmx6_Makefile feeds/routing/bmx6/Makefile

# ar71xx hardcoded
./cooker -b ar71xx/generic --force-local
