# distance

    option mcast_rate 5000

A distance of 5 km is used because it was recommended by qmp.cat

according to the official wiki on [wireless user-guide](https://openwrt.org/docs/guide-user/network/wifi/basic#common_options) says it is a *driver default* (is that meaning that it is automatically done?). The description says:

> Distance between the ap and the furthest client in meters.

# mcast_rate

    option mcast_rate 6000

It appears as a [common configuration for all mesh routing protocols](https://battlemesh.org/BattleMeshV5/Configurations)

[In this article](https://www.battlemesh.org/BattleMeshV4/MeshGuide), describes with detail what it is and why that value

> Wifi radios usually have a range of bitrates they can transmit at. Usually, they are configured such that they will attempt to transmit at the highest bitrate, but will back off to lower bitrates if there is too much noise, or if for some reason there is low transmit quality.
>
> Multicast packets, however, are usually transmitted at the lowest possible bitrate: 1Mbit/s. That's because lower-bitrate traffic will usually have less packet-loss. If we're broadcasting a packet, it's probably because we feel it's pretty important, and want everybody to be able to hear it, so that's why we decrease the bitrate.
>
> But having it on 1mbit, means protocol traffic needs more airtime, which especially in large networks -- networks with more protocol traffic -- gets to be an issue. And additionally 1mbit mcast-rate means that the link-quality detection which is based on packetloss or protocol traffic, will test the link with an quite "unrealistic" rate, leading to detection of links which for any higher througput are undesireable anyways.
>
> Therefore in many community networks we usually use a higher multicast rate, such as 6Mbit/s

according to the official wiki on [wireless user-guide](https://openwrt.org/docs/guide-user/network/wifi/basic#common_options) says it is a *driver default* (is that meaning that it is automatically done?). The description says:

> Sets the fixed multicast rate, measured in kb/s. Only supported in adhoc mode
