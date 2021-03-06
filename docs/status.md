<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Status](#status)
  - [General](#general)
  - [Device status](#device-status)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Status

### General

Work in progress

- with official openwrt should work by default, just `rake`
- with custom firmware requires manual operations and the documentation is not clean/finished

### Device status

- regular-nanostation-m

    - note: Nanostation M5 XM and Nanostation M5 XW uses this firmware
    - [x] template
    - [x] tested in '17.01.4'
    - [x] in production
        - 10.1.58.65 with temba commit d4f4256
        - 10.1.56.161
        - 10.1.57.33
        - 10.1.57.225
        - etc.

- regular-nanostation-m-xw

    - note: template is based on a node running in production (10.1.71.97)
    - [x] template
    - [x] tested in '17.01.4'
    - [x] in production
      - 10.1.57.193
      - 10.1.58.161

- regular-nanostation-loco-m-xw

    - note:
        - template is based on a node running in production (10.1.73.65)
        - [PowerBeam M5-300 uses this firmware](https://openwrt.org/toh/ubiquiti/powerbeam?s[]=powerbeam) but **is not going to work properly** see [#63](https://gitlab.com/guifi-exo/temba/issues/63)
    - [x] template
    - [x] tested in '17.01.4'
      - 10.1.56.97

- regular-rocket-m

    - note: template is based on a node running in production (10.1.72.1)
        - observeu que en el cas de la Rocket, he afegit una nova iface WAN per connectar a un router ADSL (per exemple) a través d'una VLAN
    - [ ] template
    - [ ] tested in '17.01.4'

- regular-rocket-m-xw

    - notes:
        - checked 10.1.27.129 as reference, it is similar to nanostation-loco-m-xw
        - [PowerBeam M5-400 uses this firmware](https://openwrt.org/toh/ubiquiti/powerbeam?s[]=powerbeam)
    - [x] template
    - [x] tested in '17.01.4'
    - [x] in production
      - 10.1.192.129 (Powerbeam M5-400)

- regular-bullet-m

    - notes:
        - template inspired from a a running node with qMp 3.2.1 (10.1.12.193)
        - [Nanobridge](https://openwrt.org/toh/ubiquiti/airmaxm) runs this target
    - [x] template
    - [x] tested in '17.01.4'
    - [ ] in production

- regular-ALFANX
    - [x] template
    - [x] tested in '17.01.4'

- border-nanostation-m-xw

    - note: template is based on a node running in production (strange bgp: 10.1.66.161, normal bgp: 10.1.71.161)
    - [x] template
    - [ ] tested in '17.01.4'

