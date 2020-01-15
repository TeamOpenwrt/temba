#!/bin/bash

# src https://openwrt.org/docs/guide-developer/quickstart-build-images

# multiline with comments -> src https://stackoverflow.com/a/12814475

packagelist=(
  # openwrt build requirements
  build-essential file python gawk zlib1g-dev libncurses5-dev rsync subversion
  # temba cli (rake) requirements
  wget zip ruby-archive-zip xz-utils rake
  # use debian stable packages
  pry ruby-ipaddress
)

sudo apt-get install ${packagelist[@]}
