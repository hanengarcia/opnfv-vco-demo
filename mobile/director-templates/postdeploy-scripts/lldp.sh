#!/bin/bash
for i in `ls /sys/class/net/ | grep 'eth\|ens\|eno\|enp'` ;
      do echo "enabling lldp for interface: $i" ;
      lldptool set-lldp -i $i adminStatus=rxtx  ;
      lldptool -T -i $i -V  sysName enableTx=yes;
      lldptool -T -i $i -V  portDesc enableTx=yes ;
      lldptool -T -i $i -V  sysDesc enableTx=yes;
      lldptool -T -i $i -V sysCap enableTx=yes;
      lldptool -T -i $i -V mngAddr enableTx=yes;
done
