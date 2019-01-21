# the library changed from debian8 to debian9

#!/bin/bash
. options.conf

routing_feed="$feeds_dir/routing"
echo "Patch will be applied to $routing_feed/bmx6"

[ ! -d $routing_feed ] && {
  echo "$routing_feed does not exist. Before applying this snippet you must clone the feeds (option -f of cooker)"
  exit 1
}

patch_file="$PWD/$tmp_dir/999-fix-bmx6_json.patch"

cat > $patch_file << EOF
--- a/lib/bmx6_json/json.c
+++ b/lib/bmx6_json/json.c
@@ -27,7 +27,7 @@
 #include <unistd.h>
 #include <fcntl.h>
 #include <stdint.h>
-#include <json/json.h>
+#include <json-c/json.h>
 //#include <dirent.h>
 //#include <sys/inotify.h>
EOF

( cd $routing_feed && mkdir -p bmx6/patches && mv $patch_file bmx6/patches/ && {
  echo "Patch copied"
} || echo "Patch copy error, maybe it is already applied or OpenWRT source has changed" )
