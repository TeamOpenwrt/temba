# Nanostation M5 XM (32 MB RAM)

qMp Clearance 3.2, master rev.9782ba8-20160121_1921 ram usage from a device in production, example 1, one long distance link

```
# free -h
             total         used         free       shared      buffers
Mem:         28708        26632         2076          888         1440
-/+ buffers:              25192         3516
Swap:            0            0            0
```

qMp Clearance 3.2, master rev.9782ba8-20160121_1921 ram usage from a device in production, example 2, very confident device...?

```
# free -h
             total         used         free       shared      buffers
Mem:         28708        23356         5352          452         1132
-/+ buffers:              22224         6484
Swap:            0            0            0
```

qMp Clearance 3.2, master rev.9782ba8-20160121_1921 ram usage from a device in production, example 2, lots of wifi links

```
# free -h
             total         used         free       shared      buffers
Mem:         28708        26648         2060          768         1036
-/+ buffers:              25612         3096
Swap:            0            0            0
```

temba 18.06.1 ram usage from a device in production, example 1, relatively idle

```
# free -h
             total       used       free     shared    buffers     cached
Mem:         27832      22920       4912        824       2360       7388
-/+ buffers/cache:      13172      14660
Swap:            0          0          0
```

early temba based on Reboot (17.01.4, r3560-79f57e422d), example 2, with lots of links

```
# free -h
             total       used       free     shared    buffers     cached
Mem:         28176      25904       2272        432       2460       5876
-/+ buffers/cache:      17568      10608
Swap:            0          0          0
```
