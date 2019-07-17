#!/bin/bash

set -e

# Use this script to build an image builder as community cooker
# dependencies of image builder are in install_temba_cli.sh

# From openwrt source to the image builder that lets us to build custom files and package for the same base customized firmware

###
# Default fallback parameters
#   the most interesting architecture # for antennas is ar71xx
archs=(ar71xx)
#   do not create-update-install feeds
syncfeeds='n'
#   a version that just works
openwrt_version='v18.06.4'

###
# Load options and arguments
if [[ ! -f imagebuilder-options ]]; then
  echo '  File imagebuilder-options does not exist.'
  echo '    Copying imagebuilder-options.example to imagebuilder-options'
  cp imagebuilder-options.example imagebuilder-options
fi
source imagebuilder-options

###
# Get repo and appropriate version of Openwrt
[[ ! -d Openwrt ]] && git clone https://github.com/Openwrt/Openwrt.git
cd Openwrt
git checkout "$openwrt_version"

###
# Custom packages - enable dtun package
if [[ $dtun = 'y' ]]; then
  dtun_git='src-git dtun https://gitlab.com/guifi-exo/dtun.git;master'
  ! grep -q "$dtun_git" feeds.conf &> /dev/null && echo "$dtun_git     # dtun: a custom package we use" >> feeds.conf
  dtun_config=$(cat << _EOF || :
# custom package to use gre with dynamic IPs
CONFIG_PACKAGE_dtun=y
_EOF
)
  #  when using feeds.conf (because of custom packages) feeds.conf.default is ignored according to https://openwrt.org/docs/guide-developer/feeds#feed_configuration
  #  solve it in a incomplete but effective manner
  git_aux='https://git.openwrt.org/feed/packages.git'
  ! grep -q "$git_aux" feeds.conf && cat feeds.conf.default >> feeds.conf
fi

###
# Feeds operations
#   note: if you do changes on feeds you have to reapply patches
if [[ $syncfeeds = 'y' || ! -d feeds ]]; then
  if [[ $syncfeeds = 'n' ]]; then
    echo '  Non existing feeds directory. Bootstrapping feeds'
  fi
  ./scripts/feeds update -a
  ./scripts/feeds install -a
fi

###
# Custom Patches
if [[ $patches = 'y' ]]; then
  #  international waters behavior
  cp ../patches/999-international-waters.patch package/firmware/wireless-regdb/patches/
  #  fixed bmx6 version (hard compatibility with qMp 3.2.1)
  cp ../patches/bmx6_Makefile feeds/routing/bmx6/Makefile
  mkdir -p feeds/routing/bmx6/patches/
  cp ../patches/999-fix-bmx6_json.patch feeds/routing/bmx6/patches/999-fix-bmx6_json.patch
fi

###
# Architecture: x86_64 or ar71xx ?
arch_config='# arch config'
for arch in ${archs[@]}; do
  case $arch in
    x86_64)
      #  save multiline in variable -> src https://stackoverflow.com/questions/23929235/multi-line-string-with-extra-space-preserved-indentation
      #  https://stackoverflow.com/questions/42501480/why-bash-stops-with-parameter-e-set-e-when-it-meets-read-command
      read -r -d '' arch_config << _EOF || :
$arch_config
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
_EOF
    ;;
    ar71xx)
    read -r -d '' arch_config << _EOF || :
$arch_config
CONFIG_TARGET_ar71xx=y
CONFIG_TARGET_ar71xx_generic=y
CONFIG_TARGET_ar71xx_generic_DEVICE_ubnt-nano-m-xw=y
_EOF
    ;;
    *)
    echo 'architectures available are x86_64 and/or ar71xx'
    exit 1
    ;;
  esac
done

###
# Make openwrt
#   apply non-interactive configuration
#     note: if you add extra packages later you have to do `make clean` to recompile image builder
cat > .config << _EOF
$arch_config
# it is better to specify a concrete target, if no targets are specified then all are compiled: slower process
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
CONFIG_PACKAGE_xl2tpd=y
CONFIG_PACKAGE_wireguard=m
CONFIG_PACKAGE_luci-app-wireguard=m
CONFIG_PACKAGE_gre=y
$dtun_config
# looks like is a requirement for gre (?)
CONFIG_PACKAGE_kmod-usb-ohci=y
# option to kstripped images to save more space
CONFIG_LUCI_SRCDIET=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
#CONFIG_ATH_USER_REGD=y
# configure image builder
CONFIG_IB=y
CONFIG_IB_STANDALONE=y
_EOF
# Prepare-validate non-interactive configuration
make defconfig
# Sanity check: RAM memory -> src https://stackoverflow.com/questions/29271593/bash-check-for-amount-of-memory-installed-on-a-system-as-sanity-check
totalm=$(free -m | awk '/^Mem:/{print $2}')
if [[ $totalm -lt 4096 ]]; then
  echo '  WARNING: your system has less than 4 GB of RAM, compilation can fail. See https://gitlab.com/guifi-exo/temba/blob/master/docs/imagebuilder.md#compilation-requirements'
fi
# Compile
#   detect script running as root -> src https://askubuntu.com/questions/15853/how-can-a-script-check-if-its-being-run-as-root
if [[ $EUID -ne 0 ]]; then
  make -j$(nproc)
else
  echo '  Warning: `tar` do not want to run configure as root, using FORCE_UNSAFE_CONFIGURE to make imagebuilder'
  FORCE_UNSAFE_CONFIGURE=1 make -j$(nproc)
fi

###
# Organize image builder(s)
cd ..
mkdir -p imagebuilder_local/
cd imagebuilder_local/

for arch in ${archs[@]}; do
  platform="$(echo $arch | cut -d'_' -f1)"
  platform_type="$(echo $arch | cut -d'_' -f2)"
  [[ $platform = $platform_type ]] && platform_type="generic"
  ib_d="openwrt-imagebuilder-${platform}-${platform_type}.Linux-x86_64"
  ln -sf ../Openwrt/bin/targets/${platform}/${platform_type}/${ib_d}.tar.xz
  echo "  Removing old $arch image builder $(pwd)/$ib_d ..."
  rm -rf "$ib_d" # remove old archive
  echo "  Decompressing new $arch image builder $(pwd)/$ib_d ..."
  tar xf "${ib_d}.tar.xz"
done
