#!/bin/bash

# checked with `shellcheck -x imagebuilder.sh`

set -e

# Use this script to build an image builder as community cooker
# dependencies of image builder are in install_temba_cli.sh

# From openwrt source to the image builder that lets us to build custom files and package for the same base customized firmware

# copy example files as production files if they do not exist -> src https://stackoverflow.com/questions/9392735/linux-how-to-copy-but-not-overwrite/9392784#9392784
cp -vn 'imagebuilder-options'{.example,}
cp -vn 'imagebuilder-customfuns.sh'{.example,}

# allow to use custom image builder options (for example, to maintain different image builders in parallel)
ib_opt="$1"
[ -z "$ib_opt" ] && ib_opt='imagebuilder-options'

# shellcheck source=imagebuilder-options
source "$ib_opt"

# custom functions for imagebuilder can be defined in ib_opt, if not, put another one
[ -z "$ib_fun" ] && ib_opt='imagebuilder-customfuns.sh'
# shellcheck source=imagebuilder-customfuns.sh
source "$ib_fun"

###
# Get repo and appropriate version of Openwrt
[[ ! -d "$openwrt_relpath" ]] && git clone https://github.com/Openwrt/Openwrt.git "$openwrt_relpath"
cd "$openwrt_relpath"
git checkout "$openwrt_version"

###
# Define packages available and installed in custom firmware for .config

# ensure unique elements in arrays -> src https://stackoverflow.com/questions/13648410/how-can-i-get-unique-values-from-an-array-in-bash/17562858#17562858
available_packages_uniq=( $(printf "%s\n" "${available_packages[@]}" | sort -u) )
installed_packages_uniq=( $(printf "%s\n" "${installed_packages[@]}" | sort -u) )
# avoid same element in both arrays -> src https://stackoverflow.com/questions/7870230/array-intersection-in-bash/7870414#7870414
for a in "${available_packages_uniq[@]}"; do
  for i in "${installed_packages_uniq[@]}"; do
    if [[ $a = "$i" ]]; then
      echo -e "\n  ERROR: package $a is in both arrays available_packages and installed_packages. Review file imagebuilder-options" && exit 1
    fi
  done
done

available_packages_config='# available packages'
for p in "${available_packages_uniq[@]}"; do
    #  save multiline in variable -> src https://stackoverflow.com/questions/23929235/multi-line-string-with-extra-space-preserved-indentation
    #  https://stackoverflow.com/questions/42501480/why-bash-stops-with-parameter-e-set-e-when-it-meets-read-command
    a_p="CONFIG_PACKAGE_$p=m"
    read -r -d '' available_packages_config << _EOF || true
$available_packages_config
$a_p
_EOF
done

installed_packages_config='# installed packages'
for p in "${installed_packages_uniq[@]}"; do
    i_p="CONFIG_PACKAGE_$p=y"
    read -r -d '' installed_packages_config << _EOF || true
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

# the rest of the script apply all of this for each architecture
  # ensure unique elements
archs_uniq=( $(printf "%s\n" "${archs[@]}" | sort -u) )
for arch in "${archs_uniq[@]}"; do
  ###
  # Fetch architecture
      # note: the approach is to compile a concrete subtarget is specified to avoid compiling all subtargets
  arch_config='# arch config'
  case $arch in
    ar71xx_generic)
    read -r -d '' arch_config << _EOF || true
$arch_config
CONFIG_TARGET_ar71xx=y
CONFIG_TARGET_ar71xx_generic=y
CONFIG_TARGET_ar71xx_generic_DEVICE_ubnt-nano-m-xw=y
_EOF
    ;;
    ath79_generic)
    read -r -d '' arch_config << _EOF || true
$arch_config
CONFIG_TARGET_ath79=y
CONFIG_TARGET_ath79_generic=y
CONFIG_TARGET_ath79_generic_DEVICE_ubnt_lap-120=y
_EOF
    ;;
    octeon_generic)
    read -r -d '' arch_config << _EOF || :
$arch_config
CONFIG_TARGET_octeon=y
_EOF
    ;;
    ramips_mt7621)
    read -r -d '' arch_config << _EOF || true
$arch_config
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_ramips_mt7621_Default=y
_EOF
    ;;
    x86_64)
      read -r -d '' arch_config << _EOF || true
$arch_config
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
_EOF
    ;;
    x86_geode)
      read -r -d '' arch_config << _EOF || :
$arch_config
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_geode=y
_EOF
    ;;
    *)
    echo "  architectures available are ar71xx, ath79, x86_64, ramips"
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
  if [[ $EUID -eq 0 ]]; then
    echo -e "\n  Warning: \`tar\` do not want to run configure as root, using \`export FORCE_UNSAFE_CONFIGURE=1\` to make imagebuilder"
    export FORCE_UNSAFE_CONFIGURE=1
  fi

  # run compilation process, if it fails, runs compilation in debug mode to see errors
  (
    echo -e "\n\n  [$arch] do: \`make -j$(nproc)\`\n\n"
    make -j"$(nproc)"
  ) || (
    echo -e "\n\n  [$arch] common compilation failed, debug: \`make V=s\`\n\n"
    make V=s
  )

  ###
  # Organize image builder(s)
  cd .. # to temba directory
  mkdir -p imagebuilder_local/
  cd imagebuilder_local/

  platform="$(echo "$arch" | cut -d'_' -f1)"
  platform_type="$(echo "$arch" | cut -d'_' -f2)"
  # image builder directory in openwrt
  ib_d="openwrt-imagebuilder-${platform}-${platform_type}.Linux-x86_64"
  # alternate location if not found -> src https://stackoverflow.com/questions/8049132/how-can-i-detect-whether-a-symlink-is-broken-in-bash/8049186#8049186
  [[ ! -e "$ib_d" ]] && ib_d="openwrt-imagebuilder-${platform}.Linux-x86_64"
  # image builder custom directory for temba usage
  ib_cd="openwrt-imagebuilder-${platform}-${platform_type}.Linux-x86_64__$openwrt_relpath"
  ln -sf ../"$openwrt_relpath"/bin/targets/"$platform"/"$platform_type"/"$ib_d".tar.xz "$ib_cd".tar.xz
  echo "  Removing old $arch custom image builder $(pwd)/$ib_cd ..."
  rm -rf "$ib_cd" # remove previous custom directory
  echo "  Decompressing new $arch custom image builder $(pwd)/${ib_cd}.tar.xz ..."
  # custom extraction of directory -> src https://askubuntu.com/questions/45349/how-to-extract-files-to-another-directory-using-tar-command/792063#792063
  mkdir -p "${ib_cd}"
  tar xf "${ib_cd}.tar.xz" -C "${ib_cd}" --strip-components=1
  cd ../"$openwrt_relpath"
done
