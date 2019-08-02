# image builder documentation

<!-- START doctoc.sh generated TOC please keep comment here to allow auto update -->
<!-- DO NOT EDIT THIS SECTION, INSTEAD RE-RUN doctoc.sh TO UPDATE -->
**Table of Contents**

- [Introduction](#introduction)
- [Compilation requirements](#compilation-requirements)
- [Usage](#usage)
  - [Add package and prepare new image builder](#add-package-and-prepare-new-image-builder)
    - [From scratch method](#from-scratch-method)
    - [Reusing method (work in progress)](#reusing-method-work-in-progress)
      - [Another examples with another packages](#another-examples-with-another-packages)
  - [show (target) profile list](#show-target-profile-list)
  - [image builder detect when you exceed space](#image-builder-detect-when-you-exceed-space)
  - [cleaning up](#cleaning-up)
  - [missing package](#missing-package)
- [Architectures](#architectures)

<!-- END doctoc.sh generated TOC please keep comment here to allow auto update -->

## Introduction

The method described here compiles the tools to do the image builder and after that allows you to run custom firmware. What says official documentation about image builder and SDK?

- why image builder? want to mass-flash dozens of devices and you need a specific firmware setup -> src https://openwrt.org/docs/guide-user/additional-software/imagebuilder
- why sdk? Recompile existing packages with custom patches or different features -> src https://openwrt.org/docs/guide-developer/using_the_sdk

looks like that with image builder you can do everything

extra feature: once you have done the image builder it works offline (without internet)

## Compilation requirements

The required libraries and tools can be installed with the script [install_temba_cli.sh](../install_temba_cli.sh). More info, check [dependencies according to openwrt wiki](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem#examples_of_package_installations)

[The station that will perform the compilation requires 4 GB of RAM according to openwrt wiki](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem#prerequisites)

I discovered that I run out of RAM when I saw this message and this [forum post explaining something similar](https://forum.archive.openwrt.org/viewtopic.php?id=55367&p=17), then I remembered that my Virtual Machine only had 1 GB of RAM (!)

```
make[4]: Entering directory '/root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0-initial/gcc'
build/genautomata /root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0/gcc/common.md /root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0/gcc/config/mips/mips.md \
  insn-conditions.md > tmp-automata.c
/bin/bash: line 1: 28896 Killed                  build/genautomata /root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0/gcc/common.md /root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0/gcc/config/mips/mips.md insn-conditions.md > tmp-automata.c
Makefile:2278: recipe for target 's-automata' failed
make[4]: *** [s-automata] Error 137
make[4]: Leaving directory '/root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0-initial/gcc'
Makefile:4210: recipe for target 'all-gcc' failed
make[3]: *** [all-gcc] Error 2
make[3]: Leaving directory '/root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0-initial'
Makefile:36: recipe for target '/root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0-initial/.built' failed
make[2]: *** [/root/temba/Openwrt/build_dir/toolchain-mips_24kc_gcc-7.3.0_musl/gcc-7.3.0-initial/.built] Error 2
make[2]: Leaving directory '/root/temba/Openwrt/toolchain/gcc/initial'
time: toolchain/gcc/initial/compile#5.06#0.81#6.49
toolchain/Makefile:98: recipe for target 'toolchain/gcc/initial/compile' failed
make[1]: *** [toolchain/gcc/initial/compile] Error 2
make[1]: Leaving directory '/root/temba/Openwrt'
/root/temba/Openwrt/include/toplevel.mk:216: recipe for target 'toolchain/gcc/initial/compile' failed
make: *** [toolchain/gcc/initial/compile] Error 2
```

## Usage

use [imagebuilder.sh](../imagebuilder.sh) script as a helper to build the environment to run the *image builder*

This is an advanced topic, so it is preferred that you read the script and understand it. If you have questions ask (you can open an issue as a question), merge requests improving documentation are very welcome.

### Add package and prepare new image builder

use case I experienced: you spend a lot of time and resources to make your custom firmware, works great but after certain time you found a new package you want to include:

- it is a kernel module so you cannot use official openwrt kernel modules because the different kernel signature you will end up with a kernel panic. So you have to include it

you have to do everything from scratch? No, just rebuild everything described in the `from scratch method`. `Reusing method` still is still work in progress, help appreciated

#### From scratch method

remove compiled stuff

    make clean

if you need to add custom feeds do `./scripts/feeds update -a` and `./scripts/feeds install -a`

then edit `.config`:

- interactive method: `make menuconfig`
- follow the `.config` edit method used in [install_imagebuilder.sh](../install_imagebuilder.sh) and after that do `make defconfig`

compile everything again

    make -j$(nproc)

some stats about this method:

- everything compiled used ~11 GB only ar7xx
- after `make clean` directory size it goes down to ~7 GB
- when doing again the `make -j$(nproc)` compile everything again takes around 10 minutes with 8 cores and *Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz*

#### Reusing method (work in progress)

edit `.config` and `make defconfig` or do it through interactive method with `make menuconfig`

recompile the package, for example GRE

    make package/network/config/gre/compile

do imagebuilder again

    make -j$(nproc) target/imagebuilder/install

but after redoing image builder, new image builder does not have the new changes, missing something

##### Another examples with another packages

protobuf package (and debugging/seeing the whole compilation process):

    make V=s package/feeds/packages/protobuf-c/host/compile

linux kernel

    make target/linux/compile

build custom package dtun

    make package/feeds/dtun/dtun-lede/compile

clean just image builder

    make target/imagebuilder/clean

### show (target) profile list

*useful for developing more profiles and understand that part of openwrt*

go to the imagebuilder directory, `make` will show you what can you do

```
 $ make
Available Commands:
    help:   This help text
    info:   Show a list of available target profiles
    clean:  Remove images and temporary build files
    image:  Build an image (see below for more information).
```

`make info` lists the profiles for that architecture

in `cooker` appears like this:

```
list_profiles() {
    local target="$1"
    [ ! -d $release/$target/ib ] && download_ib $target
    make -C $release/$target/ib info
}
```

also, when a profile does not exist, this command is highlighted

```
    >>> make -C ./lede-imagebuilder-17.01.4-ar71xx-generic.Linux-x86_64  image PROFILE=ALFA-NX PACKAGES='bmx6-json bmx6-sms bmx6-uci-config bmx6-table luci luci-ssl luci-app-bmx6 tcpdump-mini iperf3 netperf ip iwinfo netcat mtr'  FILES=./files_generated




make: Entering directory '/home/music/dev/temba/lede-imagebuilder-17.01.4-ar71xx-generic.Linux-x86_64'
Profile "ALFA-NX" does not exist!
Use "make info" to get a list of available profile names.
```

### image builder detect when you exceed space

for example:

    [mktplinkfw] *** error: images are too big by 31468 bytes

### cleaning up

these methods from openwrt documentation are useful to apply to image builder: https://openwrt.org/docs/guide-developer/build-system/use-buildsystem#cleaning_up

### missing package

I required a package in order to build firmware for *tplink_cpe510-v3* (or new devices ath79 in snapshot (?))

This is how it looked the error message when using `rake` for that target

```
Collected errors:
 * opkg_install_cmd: Cannot install package rssileds.
Makefile:152: recipe for target 'package_install' failed
make[2]: *** [package_install] Error 255
Makefile:111: recipe for target '_call_image' failed
make[1]: *** [_call_image] Error 2
Makefile:195: recipe for target 'image' failed
make: *** [image] Error 2
make: Leaving directory '/root/temba/imagebuilder_local/openwrt-imagebuilder-ath79-generic.Linux-x86_64'
rake aborted!
Openwrt build error. Check dependencies and requirements. Check consistency of:
    ./imagebuilder_local/openwrt-imagebuilder-ath79-generic.Linux-x86_64
    or the archive where came from openwrt-imagebuilder-ath79-generic.Linux-x86_64.tar.xz
tembalib.rb:256:in `generate_firmware'
tembalib.rb:154:in `generate_node'
tembalib.rb:63:in `block in generate_all'
tembalib.rb:58:in `each'
tembalib.rb:58:in `generate_all'
/root/temba/Rakefile:8:in `block in <top (required)>'
/var/lib/gems/2.3.0/gems/rake-12.3.2/exe/rake:27:in `<top (required)>'
Tasks: TOP => default => generate_all
(See full trace by running task with --trace)
```

# Other details

## Architectures

From https://openwrt.org/docs/techref/targets/ath79 -> "ath79 is the successor of ar71xx. It's modernization under the hood, with the main goal to bring the code into a form that is acceptable for Linux upstream, so that all (most) of the whole ar71xx supported devices can be handled by an upstream, unpatched Linux kernel"

At the moment is unclear what will happen with 19.07. Some people says that It was decided this way: "ships ar71xx and ath79 source-only", after that release "ships ath79 and ar71xx source-only", the reason is to save space in linux kernel image for the small devices
