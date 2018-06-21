# Temba

Buildsystem to generate custom Openwrt-Firmware files for different nodes in a community network.

If you want to control the build system my recomendation is to use [lime-sdk](https://github.com/libremesh/lime-sdk). [Instructions](https://github.com/guifi-exo/wiki/blob/master/howto/lime-sdk.md)

## Status

### General

Work in progress

- with official openwrt should work by default, just `rake`
- with custom firmware requires manual operations and the documentation is not clean/finished

### Device status

- regular-nanostation-m5

    - [x] template
    - [x] tested
    - [x] in production
        - 10.1.58.65 with temba commit d4f4256
        - 10.1.56.161
        - 10.1.57.33
        - 10.1.57.225

- regular-nanostation-m5-xw

    - note: template is based on a node running in production (10.1.71.97)
    - [x] template
    - [ ] tested

- regular-nanostation-loco-m5-xw

    - note: template is based on a node running in production (10.1.73.65)
    - [ ] template
    - [ ] tested

- regular-rocket-m5-xw

    - note: template is based on a node running in production (10.1.72.1)
        - observeu que en el cas de la Rocket, he afegit una nova iface WAN per connectar a un router ADSL (per exemple) a través d'una VLAN
    - [ ] template
    - [ ] tested

- border-nanostation-m5-xw

    - note: template is based on a node running in production (10.1.66.161)
    - [ ] template
    - [ ] tested

## Motivation

Device configuration should be:

* Consistent / [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
* Revertible - especially using `first_boot`
* Under version control

To archive these goals, a OpenWRT-configuration is generated based on Ruby `.erb` templates. A dedicated firmware file is generated for each node.

## Structure

* `10-globals.yml` - default variables that are generic for a specific community network like DNS or NTP server, what kind of Image Builder you want to use
* `20-devices.yml` - default variables that are part of a device like its packages, architecture
* `30-nodes.yml` - inventory of all nodes. A firmware-file is generated per node. You probably don't want to share this file because contains sensitive information like IP, geolocalization of node, etc.
* `files` - Directory of .ERB-templates. After processing all ERB-templates, it is integrated into the firmware files
* `bin` - Output folder for firmware files
* `Rakefile` - Central build file

## Usage

1. Adapt yml files
2. Adapt templates accordingly. They start with `template__`
3. Run `rake`

## Invisible credits

Sometimes the commits are not done by the original authors

The following templates contributed by @dyangol

- template__regular-nanostation-m5-xw
- template__border-nanostation-m5-xw

The original idea is from @yanosz and its repository https://github.com/yanosz/mesh_testbed_generator
