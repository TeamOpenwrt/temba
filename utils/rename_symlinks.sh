#!/bin/bash

# This script is a helper when you want to massively rename relative symlinks.
# It creates another script that you verify before executing it. It contains
# example when I decided to change `common` directory to `template__common`
# directory.
# Warning, if you apply again, this mess is going to happen
#
#    -../../../template__common/regular/bmx6.erb
#    +../../../template__template__common/regular/bmx6.erb

# thanks! https://superuser.com/a/157832

SRC_DIR="." # current directory
OLD_TARGET="*common*" # match symbolic link affected
SUB="s/template__common/library/" # what is the substitution you want to apply

# why ln-nsf -> src https://superuser.com/questions/81164/why-create-a-link-like-this-ln-nsf
find $SRC_DIR -type l \
  -lname "$OLD_TARGET" -printf \
  'ln -nsf "$(readlink "%p"|sed '$SUB')" "$(echo "%p"|sed '$SUB')"\n' \
  > do_rename_symlinks.sh

chmod +x do_rename_symlinks.sh

echo results:
cat do_rename_symlinks.sh
