#!/bin/bash

# multiline with comments -> src https://stackoverflow.com/a/12814475

packagelist=(
  # openwrt build requirements
  build-essential file python gawk zlib1g-dev libncurses5-dev
  # temba cli (rake) requirements
  wget zip xz-utils rake
  # temba gui (rails) requirements
  patch ruby-dev zlib1g-dev liblzma-dev nodejs rubygems-integration ruby
)

apt-get install ${packagelist[@]}

# install rails with bundle
gem install bundle
cd ror_app_form
bundle install
