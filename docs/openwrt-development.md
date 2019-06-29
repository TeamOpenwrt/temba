# skip errors

if you want to skip errors use (thanks )

    make IGNORE_ERRORS=m

explaining the different types of images https://openwrt.org/inbox/firmware_image_names

build single package: https://openwrt.org/docs/guide-developer/single.package

documentation:

- a very good article explaining Openwrt SDK (prepare packages for openwrt) http://dvblog.soabit.com/building-custom-openwrt-packages-an-hopefully-complete-guide/
- https://openwrt.org/docs/guide-developer/using_the_sdk

community: good place to learn openwrt development in general https://forum.openwrt.org/c/devel

# debug

use one core and show all raw output:

    make V=s -j1
