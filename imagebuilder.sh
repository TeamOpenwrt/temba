#!/bin/bash

set -e

# Use this script to build an image builder as community cooker
# dependencies of image builder are in install_temba_cli.sh

# From openwrt source to the image builder that lets us to build custom files and package for the same base customized firmware

###
# Custom options, arguments and functions (custom packages and patches)
custom_files=(imagebuilder-options imagebuilder-customfuns.sh)
for file in ${custom_files[@]}; do
  if [[ ! -f "$file" ]]; then
    echo "  File $file does not exist."
    echo "    Copying ${file}.example to imagebuilder-options"
    cp ${file}.example $file
  fi
  source "$file"
done

###
# Get repo and appropriate version of Openwrt
[[ ! -d Openwrt ]] && git clone https://github.com/Openwrt/Openwrt.git
cd Openwrt
git checkout "$openwrt_version"

###
# Define packages available and installed in custom firmware for .config

# ensure unique elements in arrays -> src https://stackoverflow.com/questions/13648410/how-can-i-get-unique-values-from-an-array-in-bash/17562858#17562858
available_packages_uniq=( $(printf "%s\n" "${available_packages[@]}" | sort -u) )
installed_packages_uniq=( $(printf "%s\n" "${installed_packages[@]}" | sort -u) )
# avoid same element in both arrays -> src https://stackoverflow.com/questions/7870230/array-intersection-in-bash/7870414#7870414
for a in ${available_packages_uniq[@]}; do
  for i in ${installed_packages_uniq[@]}; do
    if [[ $a = $i ]]; then
      echo -e "\nERROR: package $a is in both arrays available_packages and installed_packages. Review file imagebuilder-options" && exit 1
    fi
  done
done

available_packages_config='# available packages'
for p in ${available_packages_uniq[@]}; do
    #  save multiline in variable -> src https://stackoverflow.com/questions/23929235/multi-line-string-with-extra-space-preserved-indentation
    #  https://stackoverflow.com/questions/42501480/why-bash-stops-with-parameter-e-set-e-when-it-meets-read-command
    a_p="CONFIG_PACKAGE_$p=m"
    read -r -d '' available_packages_config << _EOF || :
$available_packages_config
$a_p
_EOF
done

installed_packages_config='# installed packages'
for p in ${installed_packages_uniq[@]}; do
    i_p="CONFIG_PACKAGE_$p=y"
    read -r -d '' installed_packages_config << _EOF || :
$installed_packages_config
$i_p
_EOF
done

###
# Feed repos
  # when using feeds.conf (because of custom packages) feeds.conf.default is ignored according to https://openwrt.org/docs/guide-developer/feeds#feed_configuration
  # default action is to always get new ones from feeds.conf
  # set holdfeeds to no if you want to freeze custom feeds
if [[ $holdfeeds = 'n' ]]; then
  cat feeds.conf.default > feeds.conf
fi

###
# Custom packages - enable dtun package
#  checks dtun_package
install_custom_packages

###
# Update and install feeds
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
#  checks qmp321_compatibility_patch and compliance_test_patch
install_custom_patches

exit

# the rest of the script apply all of this for each architecture
  # ensure unique elements
archs_uniq=( $(printf "%s\n" "${archs[@]}" | sort -u) )
for arch in ${archs_uniq[@]}; do
  ###
  # Fetch architecture
      # note: the approach is to compile a concrete subtarget is specified to avoid compiling all subtargets
  arch_config='# arch config'
  case $arch in
    x86_64)
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
    ath79)
    read -r -d '' arch_config << _EOF || :
$arch_config
CONFIG_TARGET_ath79=y
CONFIG_TARGET_ath79_generic=y
CONFIG_TARGET_ath79_generic_DEVICE_ubnt_lap-120=y
_EOF
    ;;
    *)
    echo 'architectures available are ar71xx, ath79, x86_64'
    exit 1
    ;;
  esac

  ###
  # Make openwrt
  #   apply non-interactive configuration
  #     note: if you add extra packages later you have to do `make clean` to recompile image builder
  #     extra note: you can add custom lines to .config
  cat > .config << _EOF
$arch_config

$available_packages_config

$installed_packages_config

$dtun_config

# option to kstripped images to save more space
CONFIG_LUCI_SRCDIET=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
# configure image builder
CONFIG_IB=y
CONFIG_IB_STANDALONE=y

$compliance_test_config
_EOF
  # this is the place to debug .config, because defconfig rewrites the file in another format
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
  cd .. # to temba directory
  mkdir -p imagebuilder_local/
  cd imagebuilder_local/

  platform="$(echo $arch | cut -d'_' -f1)"
  platform_type="$(echo $arch | cut -d'_' -f2)"
  [[ $platform = $platform_type ]] && platform_type="generic"
  ib_d="openwrt-imagebuilder-${platform}-${platform_type}.Linux-x86_64"
  ln -sf ../Openwrt/bin/targets/${platform}/${platform_type}/${ib_d}.tar.xz
  echo "  Removing old $arch image builder $(pwd)/$ib_d ..."
  rm -rf "$ib_d" # remove old archive
  echo "  Decompressing new $arch image builder $(pwd)/$ib_d ..."
  tar xf "${ib_d}.tar.xz"
  cd ../Openwrt
done
