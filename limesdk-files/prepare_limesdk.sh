#!/bin/bash

## work in progress (only intended to work on 18.06.1)

# TODO
# - ar71xx hardcoded

set -e   # causes the shell to exit if any subcommand or pipeline returns a non-zero status.
set -v

# thanks https://unix.stackexchange.com/a/52801
if [[ $(dirname $0) != . ]]; then
  echo 'ERROR: execute script in the same directory (no absolute nor relative path)'
  exit 1
fi

# src https://gitlab.com/guifi-exo/wiki/blob/master/howto/lime-sdk.md
git clone https://github.com/libremesh/lime-sdk ../../lime-sdk -b develop

cd ../../lime-sdk

git checkout 943c4ad3d4f3cb8982c530e5d00ff7fa08cbf1d5

# override release
cp ../temba/limesdk-files/options.conf.local .
cp ../temba/limesdk-files/flavors.conf.local .
# these feeds are not working (I suspect that is because libremesh packages are
#  missing and the options.conf assumes are there)
#cp ../temba/limesdk-files/feeds.conf.temba .

# cooker does not work from other link
./cooker -f

# apply patches
snippets/regdbtz.sh
cp ../temba/limesdk-files/fix_bmx6_json.sh snippets/
snippets/fix_bmx6_json.sh

# get specific version of bmx6 -> src https://gitlab.com/guifi-exo/wiki/blob/master/howto/openwrt_template.md
# more https://github.com/bmx-routing/bmx6/tree/2a87b770d3f9c254e3927dc159e2f425f2e0e83a
# warning: this assumes temba git repo is named temba and it is in the same level as lime-sdk
cp ../temba/limesdk-files/bmx6_Makefile feeds/routing/bmx6/Makefile

# compile through SDK and bind to IB (use profile ubnt-loco-m-xw as an example)
./cooker -b ar71xx/generic --profile=ubnt-loco-m-xw --flavor=patched --force-local
# troubleshooting: this is how to debug compilation problems
## J=1 V=s ./cooker -b ar71xx/generic --profile=ubnt-loco-m-xw --flavor=patched --force-local
# compile and finish the IB binding to SDK
./cooker -c ar71xx/generic --profile=ubnt-loco-m-xw --flavor=patched

# at this point when you use IB through temba the custom patches are considered
