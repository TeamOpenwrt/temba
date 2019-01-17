notes useful for developing more profiles and understand that part of openwrt

# about the (target) profile list

the file that I download, if I enter it `cd lede-imagebuilder-17.01.4-ar71xx-generic.Linux-x86_64`

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
