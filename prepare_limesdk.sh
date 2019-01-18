set -e   # causes the shell to exit if any subcommand or pipeline returns a non-zero status.
set -v

# src https://gitlab.com/guifi-exo/wiki/blob/master/howto/lime-sdk.md
git clone https://github.com/libremesh/lime-sdk ../lime-sdk

cd ../lime-sdk

# override release
## release hardcoded (TODO)
cat > options.conf.local <<EOF
#release=17.01.4
release=18.04.1
base_url=https://downloads.openwrt.org/releases/$release/targets/
communities_git=https://github.com/libremesh/network-profiles.git
communities_dir=communities
tmp_dir=tmp
#feeds_default_file=feeds.conf.default
feeds_default_file=feeds.conf.temba
feeds_file=feeds.conf
feeds_dir=feeds
files_dir=files
flavors_file=flavors.conf
sdk_config=libremesh.sdk.config
sdk_install_packages="libustream-openssl firewall"
sdk_install_repos="libremesh libremap limeui"
remote_pkg_repos="libremesh.repositories.conf"
default_flavor="lime_default"
targets_list=targets.list
downloads_dir=dl
make_j=1
bin_output=output
brand_name=lede
EOF

## release hardcoded (TODO)
cat > feeds.conf.temba <<EOF
src-git base https://git.openwrt.org/openwrt/openwrt.git^70255e3d624cd393612069aae0a859d1acbbeeae
src-git packages https://git.openwrt.org/feed/packages.git^35e0b737ab496f5b51e80079b0d8c9b442e223f5
src-git luci https://git.openwrt.org/project/luci.git^f64b1523447547032d5280fb0bcdde570f2ca913
src-git routing https://git.openwrt.org/feed/routing.git^1b9d1c419f0ecefda51922a7845ab2183d6acd76
src-git telephony https://git.openwrt.org/feed/telephony.git^b9d7b321d15a44c5abb9e5d43a4ec78abfd9031b
EOF

# cooker does not work from other link
./cooker -f

# optional patch
../lime-sdk/snippets/regdbtz.sh

# get specific version of bmx6 -> src https://gitlab.com/guifi-exo/wiki/blob/master/howto/openwrt_template.md
# more https://github.com/bmx-routing/bmx6/tree/2a87b770d3f9c254e3927dc159e2f425f2e0e83a
# warning: this assumes temba git repo is named temba and it is in the same level as lime-sdk
cp ../temba/bmx6_Makefile feeds/routing/bmx6/Makefile

# ar71xx hardcoded (TODO)
./cooker -b ar71xx/generic --force-local
