<!-- START doctoc.sh generated TOC please keep comment here to allow auto update -->
<!-- DO NOT EDIT THIS SECTION, INSTEAD RE-RUN doctoc.sh TO UPDATE -->
**Table of Contents**

- [Structure](#structure)
- [Install](#install)
  - [temba cli (rake)](#temba-cli-rake)
  - [temba gui (rails)](#temba-gui-rails)
- [Usage](#usage)
  - [20-devices.yml](#20-devicesyml)
- [Run x86_64 in qemu](#run-x86_64-in-qemu)
- [Testbed](#testbed)
- [Notation & coding style](#notation--coding-style)
- [Motivation](#motivation)
- [Invisible credits](#invisible-credits)
- [Similar projects](#similar-projects)

<!-- END doctoc.sh generated TOC please keep comment here to allow auto update -->

# Temba

what is it: is a tool to build openwrt firmware

how it works: erb templates on config files per device (some files are shared) evaluated from inherited yaml files with two interfaces: rake and rubyonrails form.

Buildsystem to generate custom Openwrt-Firmware files for different nodes in a community network.

At the moment this is serving postqMp community and eXO.cat with bmx6 (note that VLAN 12 on ethernet is untagged). I'm open to generalize the solution, but as this is just me working on this I will continue this way.

If you want to control the build system my recomendation is to use [install_imagebuilder.sh]() script. Check documentation [here](docs/imagebuilder.md). [There are other image builder frontends you would like to check](https://openwrt.org/docs/guide-developer/imagebuilder_frontends). Temba in the past started using [lime-sdk](https://github.com/libremesh/lime-sdk) ([notes on lime-sdk instructions](https://github.com/guifi-exo/wiki/blob/master/howto/lime-sdk.md)). Maybe [openwrt-metabuilder](https://github.com/aparcar/openwrt-metabuilder) is the natural evolution of lime-sdk.

[Check status of the project](./docs/status.md)

## Structure

To avoid redundancy of information we use different yaml files, you can test yaml stuff through this online app http://yaml-online-parser.appspot.com/ and here is the source code https://github.com/ptarjan/online-yaml-parser/tree/master

core yaml files:

* `10-globals.yml` - default variables that are generic for a specific community network like DNS or NTP server, what kind of Image Builder you want to use, and other default options you want to apply to your devices or nodes.
* `15-packages.yml` - sets of packages and different types of roles for devices
* `20-devices.yml` - default variables that are part of a device like its packages, architecture
* `30-nodes.yml` - inventory of all nodes. A firmware-file is generated per node. You probably don't want to share this file because contains sensitive information like IP, geolocalization of node, etc.

relevant directories:

* `files` - Directory that contains all template config files
  - `template__` - Directories with their specific .ERB-templates. After processing all ERB-templates, it is integrated into the firmware files
  - `notemplate__` - Directories with inmutable configuration that is integrated into the firmware files. This could be transitory until some generalization and templating is available for the target.
* `output` - Output folder for files and directories generated with this tool

temba cli:

* `Rakefile` - Central build file
* `tembalib.rb` - ruby code for temba cli and temba gui

temba gui:

* `ror_app_form` - directory with ruby on rails application

## Install

Requires debian 9 stable ([plus 8 GB of RAM if you want to compile openwrt](https://openwrt.org/docs/guide-user/additional-software/beginners-build-guide))

if you don't have a debian or you don't want to taint your debian you can use [docker](https://docker.com)

    docker run -h debian-temba -it -P debian:9 bash

and

    apt install git vim sudo
    git clone https://gitlab.com/guifi-exo/temba
    cd temba

### temba cli (rake)

Read and execute instructions of [install_temba_cli.sh](install_temba_cli.sh)

source:

- *Rakefile*
- *tembalib.rb*

quickstart (assuming new temba)

    cp -i 10-globals.yml.example 10-globals.yml
    cp -i 30-nodes.yml.example 30-nodes.yml
    rake

demo

![temba_cli_demo](/uploads/0245f5f2da8347f03246f9609036773e/temba_cli_demo.gif)

### temba gui (rails)

Read and execute instructions of [install_temba_gui.sh](install_temba_gui.sh)

source:

- *ror_app_form* is the rails directory
- *tembalib.rb*

quickstart: run `cd ror_app_form; ./run_rails.sh`

demo

![temba_gui_demo](/uploads/8b65848fc2742d0e24bd1d9354b4dcd0/temba_gui_demo.gif)

## Usage

1. Adapt yml files (you have 2 examples you can rename files or create on your own)
2. Adapt templates accordingly. They start with `template__`. `template__common` is a directory to share common files across different devices through relative symlinks
3. Run
    - `rake` if you want to generate firmwares
    - `rake debug` if you want to debug only templates

### 20-devices.yml

in root of buildroot file `.config` gives you details of variables used in yaml file

| variable in .config | variable in 20-devices.yml |
| ------------------- | -------------------------- |
| CONFIG_TARGET_PROFILE | profile |
| CONFIG_TARGET_BOARD | platform |
| CONFIG_TARGET_SUBTARGET | platform_type |

alternatively use `cooker` as described in [lime-sdk](https://gitlab.com/guifi-exo/wiki/blob/master/howto/lime-sdk.md#qa)

## Run x86_64 in qemu

    qemu-system-x86_64 -M q35 -drive file=bin/hostname-x86_64-combined-ext4.img,id=d0,if=none,bus=0,unit=0 -device ide-hd,drive=d0,bus=ide.0

src https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64

## Testbed

Temba facilitates the creation of testbed to improve the network. `tb` refers to be used in a testbed

The images of the following diagram can be generated running `31-testbed-nodes.yml.example`. With that images you can run [temba-qemunet](https://gitlab.com/guifi-exo/temba-qemunet) with a particular topology to run the testbed. Green (left) and blue (right) squares represent bmx6 mesh networks and red square is a bgp zone where routes are propagated . This is a common scenario in Barcelona.

![](./testbed-temba-qemunet.png)

More details to come

## Notation & coding style

wifN means wireless N=0,1,2,...

cifN means cable N=0,1,2,...

openwrt config files indented with tab and code indented by 2 spaces (as in [GNU style](https://en.wikipedia.org/wiki/Indentation_style#GNU_style))

## Motivation

Device configuration should be:

- Consistent / [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
- Revertible - especially using `first_boot`
- Under version control

To achieve these goals, a OpenWRT-configuration is generated based on Ruby `.erb` templates. A dedicated firmware file is generated for each node.

## Invisible credits

Sometimes the commits are not done by the original authors

- @dyangol and @ces10 provided great help contributing with templates, configurations, bugfix and reviewing ideas here implemented
- @ces10 did a great contribution showing an alternative method to compile from scratch the image builder
- the original idea of using ruby as helper for openwrt buildroot comes from [@yanosz](https://github.com/yanosz) and [its repository](https://github.com/yanosz/mesh_testbed_generator)
- the inspiration to do the ruby on rails form app comes from https://chef.libremesh.org, thanks [@aparcar](https://github.com/aparcar)

## Similar projects

- https://chef.libremesh.org
    - this looks similar to temba https://github.com/libremesh/network-profiles/tree/master/jardibotanic
- https://github.com/yanosz/mesh_testbed_generator
- https://github.com/openwisp/ansible-openwisp2-imagegenerator
- https://chef.altermundi.net (deprecated, unmaintained, go to chef.libremesh.org)
