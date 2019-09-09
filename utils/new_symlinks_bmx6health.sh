#!/bin/bash

# This script is a helper when you want to massively add a new symlink to all
# targets. It creates another script that you verify before executing it. It
# contains example when I decided to add dropbear authorized keys to all
# targets.

# thanks https://unix.stackexchange.com/a/52801
if [[ $(dirname $0) != . ]]; then
  echo 'ERROR: execute script in the same directory (no absolute nor relative path)'
  exit 1
fi


# thanks! https://superuser.com/a/157832

DIR="../files/" # template directory
TARGETS="template__regular*" # match symbolic link affected
SRC="library/usr-local-bin-bmx6health.sh"
DST_FILE="/usr/local/bin/bmx6health.sh" # what is the substitution you want to apply
DST_PATH="$(dirname $DST_FILE)"

# why ln-nsf -> src https://superuser.com/questions/81164/why-create-a-link-like-this-ln-nsf
find $DIR -iname "$TARGETS" -printf \
  'mkdir -p "%p'"$DST_PATH"'"; ln -nsf "../../../../'"$SRC"'" "%p'"$DST_FILE"'"\n' \
  > do_new_symlinks.sh

chmod +x do_new_symlinks.sh

echo results:
cat do_new_symlinks.sh

echo -e "\ndo_new_symlinks.sh"
