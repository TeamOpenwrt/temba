this is a situation we don't want anymore because depending on the hardware/device putting vlans through ethernet could be a simple or complex operation

but as an exception could be useful. Hence, here you have how to configure (in general) a tagged wire interface for bmx6

in /etc/config/network add

```
config device 'cif0_t'
  option type '8021q'
  option name 'cif0_t'
  option ifname '@lan'
  option vid '12'

config interface 'mesh2'
  option ifname 'cif0_t'
  option auto '1'
```

in /etc/config/bmx6 add

```
config dev 'mesh_2'
  option dev 'cif0_t'
  option linklayer '1'
```
