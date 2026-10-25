#!/bin/sh
# Rusticc idle for 40 minutes: memory at 10 and 40 minutes (growth check)
D=/user-resource/rusticc
sh $D/rusticc-switch.sh rusticc > /dev/null
sleep 600
echo "=== 10 min" > $D/leak.txt
sh $D/measure.sh $(cat /var/run/rusticc.pid) 60 >> $D/leak.txt 2>&1
sleep 1740
echo "=== 40 min" >> $D/leak.txt
sh $D/measure.sh $(cat /var/run/rusticc.pid) 60 >> $D/leak.txt 2>&1
sh $D/rusticc-switch.sh stock > /dev/null
echo "=== done" >> $D/leak.txt
