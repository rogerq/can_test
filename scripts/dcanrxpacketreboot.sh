#!/bin/sh

# bring up CAN and check if packet received and reboot

LOGFILE=dcanrxpacketreboot.log
FULLLOG=dcanrxpacketreboot.logx
if [ ! -f $LOGFILE ]; then
	echo "creating new log file"
	rm -f $FULLLOG
	touch $FULLLOG
	ITERS=0
	UP_FAIL=0
	OFF_FAIL=0
	READ_FAIL=0
else
#read values from log file
	ITERS=$(cat $LOGFILE | awk '/Boots/{print $2}')
	UP_FAIL=$(cat $LOGFILE | awk '/UP fails/{print $3}')
	OFF_FAIL=$(cat $LOGFILE | awk '/OFF fails/{print $3}')
	READ_FAIL=$(cat $LOGFILE | awk '/READ fails/{print $3}')
fi

ITERS=`expr $ITERS + 1`
CANDEV=can0
ip link set $CANDEV type can bitrate 250000 triple-sampling on
ip link set $CANDEV txqueuelen 2000

echo "DCANRXPACKETREBOOT test iteration: $ITERS"
ifconfig $CANDEV up 
sleep 1
VAL=$(devmem2 0x4AE3C000 | awk '/Read at address/{print $6}')
if [ $VAL != '0x0000000E' ] ; then
	echo $CANDEV "up failed" $i - VAL:$VAL
	UP_FAIL=`expr $UP_FAIL + 1`
fi

rm -f /tmp/candump
candump $CANDEV -o /tmp/candump &
sleep 1
killall candump

SIZE=`stat -c %s /tmp/candump`
echo "candump size $SIZE"

if [ $SIZE == '0' ] ; then
	echo $CANDEV read 0 bytes
	READ_FAIL=`expr $READ_FAIL + 1`
fi

ifconfig $CANDEV down
sleep 1
VAL=$(devmem2 0x4AE07888 | awk '/Read at address/{print $6}')
if [ $VAL != '0x00030000' ] ; then
	echo $CANDEV "off failed" $i - VAL:$VAL
	OFF_FAIL=`expr $OFF_FAIL + 1`
fi

echo "Boots: $ITERS, UP fails: $UP_FAIL, OFF fails: $OFF_FAIL, READ fails: $READ_FAIL" > /tmp/cantmplog
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
cat /tmp/cantmplog
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

cat /tmp/cantmplog >> $FULLLOG
#update log
echo "SUMMARY" > $LOGFILE
echo "Boots: $ITERS" >> $LOGFILE
echo "UP fails: $UP_FAIL" >> $LOGFILE
echo "OFF fails: $OFF_FAIL" >> $LOGFILE
echo "READ fails: $READ_FAIL" >> $LOGFILE

reboot
