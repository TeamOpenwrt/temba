#!/bin/bash

# Optional step, use a community cooker to avoid wasting resources

# From openwrt source to the image builder that lets us to build custom files and package for the same base customized firmware
# this is for 18.06.2 openwrt release

git clone https://github.com/Openwrt/Openwrt.git -b v18.06.2

cd Openwrt

cat > feeds.config.default <<EOF
src-git packages https://git.openwrt.org/feed/packages.git;openwrt-18.06
src-git luci https://git.openwrt.org/project/luci.git;openwrt-18.06
src-git routing https://git.openwrt.org/feed/routing.git;openwrt-18.06
# example to stick to a specific commit
#src-git telephony https://git.openwrt.org/feed/telephony.git^cb939d9677d6e38c428f9f297641d07611edeb04
src-git telephony https://git.openwrt.org/feed/telephony.git;openwrt-18.06

# a custom package we use
src-git dtun https://gitlab.com/guifi-exo/dtun.git
EOF

# if you do changes on feeds you have to reapply patches
./scripts/feeds update -a
./scripts/feeds install -a

# -------------------------
# available custom patches uncomment to apply

# international waters behavior
# cp patches/999-international-waters.patch package/firmware/wireless-regdb/patches/

# fixed bmx6 version (hard compatibility with qMp 3.2.1)
# cp patches/bmx6_Makefile feeds/routing/bmx6/Makefile
# mkdir -p feeds/routing/bmx6/patches/
# cp patches/999-fix-bmx6_json.patch feeds/routing/bmx6/patches/999-fix-bmx6_json.patch
# -------------------------

# non-interactive configuration
# if you add extra packages later you have to do `make clean` to recompile image builder
cat > .config <<EOF
CONFIG_TARGET_ar71xx=y
CONFIG_TARGET_ar71xx_generic=y
# it is better to specify a concrete target, if no targets are specified then all are compiled: slower process
CONFIG_TARGET_ar71xx_generic_DEVICE_ubnt-nano-m-xw=y
CONFIG_PACKAGE_bmx6-json=m
CONFIG_PACKAGE_bmx6-sms=m
CONFIG_PACKAGE_bmx6-uci-config=m
CONFIG_PACKAGE_bmx6-table=m
#CONFIG_PACKAGE_luci=m
CONFIG_PACKAGE_luci-ssl=m
CONFIG_PACKAGE_luci-app-bmx6=m
CONFIG_PACKAGE_iperf3=m
CONFIG_PACKAGE_mtr=m
CONFIG_PACKAGE_netcat=m
CONFIG_PACKAGE_netperf=m
CONFIG_PACKAGE_tcpdump-mini=m
#CONFIG_PACKAGE_iwinfo=m
CONFIG_PACKAGE_xl2tpd=m
CONFIG_PACKAGE_wireguard=m
CONFIG_PACKAGE_luci-app-wireguard=m
CONFIG_PACKAGE_gre=y
# custom package to use gre with dynamic IPs
CONFIG_PACKAGE_dtun=y
# looks like is a requirement for gre (?)
CONFIG_PACKAGE_kmod-usb-ohci=y
# option to kstripped images to save more space
CONFIG_LUCI_SRCDIET=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
#CONFIG_ATH_USER_REGD=y
# configure image builder
CONFIG_IB=y
CONFIG_IB_STANDALONE=y
EOF

make defconfig
make -j$(nproc)
# if fails, probably is because `tar` don't want to run configure as root
#FORCE_UNSAFE_CONFIGURE=1 make -j$(nproc)

# extract image builder
# TODO: check if exists a previous image builder
# at the moment this is commented to avoid destroying a useful image builder
# tar xvf bin/targets/ar71xx/generic/openwrt-imagebuilder*tar.xz
