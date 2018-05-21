# Temba

status: work in progress / works but requires several manual operations

Buildsystem to generate custom Openwrt-Firmware files for different nodes in a community network.

If you want to control the build system my recomendation is to use [lime-sdk](https://github.com/libremesh/lime-sdk). [Instructions](https://github.com/guifi-exo/wiki/blob/master/howto/lime-sdk.md)

## Motivation

Device configuration should be:

* Consistent / [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
* Revertible - especially using `first_boot`
* Under version control

To archive these goals, a OpenWRT-configuration is generated based on Ruby `.erb` templates. A dedicated firmware file is generated for each node.

## Structure

* `nodes.yml` - inventory of all nodes. A firmware-file is generated per node
* `files` - Directory of .ERB-templates. After processing all ERB-templates, it is integrated into the firmware files
* `bin` - Output folder for firmware files
* `Rakefile` - Central build file

## Usage

1. Adapt `nodes.yml`
2. Adapt templates in `files`
3. Run `rake`

OpenWRT Release (Chaos Calmer) and Platform (TL-WR842nd v2) is hardcoded in `Rakefile`. You have to change it to support other platforms.

## Invisible credits

Sometimes the commits are not done by the original authors

The following templates contributed by @dyangol

- template__regular-nanostation-m5-xw
- template__border-nanostation-m5-xw

The original idea is from @yanosz and its repository https://github.com/yanosz/mesh_testbed_generator
