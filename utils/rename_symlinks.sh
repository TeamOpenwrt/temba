#!/bin/bash

# This script is a helper when you want to massively rename relative symlinks.
# It creates another script that you verify before executing it. It contains
# example when I decided to change all symlinks that pointed to
# `template_common` to rename it to `library`
# Warning, if you apply again, symlinks are going to change to
#
#    -../../../template__common
#    +../../../library

# thanks https://unix.stackexchange.com/a/52801
if [[ $(dirname $0) != . ]]; then
  echo 'ERROR: execute script in the same directory (no absolute nor relative path)'
  exit 1
fi


# thanks! https://superuser.com/a/157832

SRC_DIR=".." # current directory
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
