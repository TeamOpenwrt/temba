#!/bin/bash

# replace everywhere (cli & gui code, templates and yaml files) a variable that affects the erb templating system

# thanks https://unix.stackexchange.com/a/52801
if [[ $(dirname $0) != . ]]; then
  echo 'ERROR: execute script in the same directory (no absolute nor relative path)'
  exit 1
fi


path_list=(
  tembalib.rb
  ror_app_form/app
  files
  "*yml"
  "*yml.example"
)

search="bmx6_tun4"
replace="ip4_cidr"

for path in "${path_list[@]}"; do

    #debug
    #echo debug ..... eval grep -lir "$search" "../$path"
    #echo debug ..... sed -i -e "s/${search}/${replace}/gi" $(eval grep -lir "$search" "../$path")
    sed -i -e "s/${search}/${replace}/gi" $(eval grep -lir "$search" "../$path")

done
