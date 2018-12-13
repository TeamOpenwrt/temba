#!/bin/bash

# This script is a helper when you want to massively add a new symlink to all
# targets. It creates another script that you verify before executing it. It
# contains example when I decided to add dropbear authorized keys to all
# targets.

# thanks! https://superuser.com/a/157832

DIR="../files/" # template directory
TARGETS="template__*" # match symbolic link affected
SRC="library/dropbear-authorized_keys.erb"
DST_PATH="/etc/dropbear"
DST_FILE="${DST_PATH}/authorized_keys.erb" # what is the substitution you want to apply

# why ln-nsf -> src https://superuser.com/questions/81164/why-create-a-link-like-this-ln-nsf
find $DIR -iname "$TARGETS" -printf \
  'mkdir -p "%p'"$DST_PATH"'"; ln -nsf "../../../'"$SRC"'" "%p'"$DST_FILE"'"\n' \
  > do_new_symlinks.sh

chmod +x do_new_symlinks.sh

echo results:
cat do_new_symlinks.sh
