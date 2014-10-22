#!/bin/sh

# repeateadly bring up and down CAN and check if packet received

ITERS=600
UP_FAIL=0
OFF_FAIL=0
PACKET_FAIL=0
CANDEV=can0
ip link set $CANDEV type can bitrate 250000 triple-sampling on
ip link set $CANDEV txqueuelen 2000
for (( i = 1 ; i <= $ITERS ; i++ ))
do
	echo "test $i"
	ifconfig $CANDEV up 
	VAL=$(devmem2 0x4AE3C000 | awk '/Value at address/{print $6}')
	if [ $VAL != '0xE' ] ; then
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
		PACKET_FAIL=`expr $PACKET_FAIL + 1`
	fi

	ifconfig $CANDEV down
	VAL=$(devmem2 0x4AE07888 | awk '/Value at address/{print $6}')
	if [ $VAL != '0x30000' ] ; then
		echo $CANDEV "off failed" $i - VAL:$VAL
		OFF_FAIL=`expr $OFF_FAIL + 1`
	fi
	echo "UP fails: $UP_FAIL/$i OFF fails: $OFF_FAIL/$i READ fails: $PACKET_FAIL/$i"
done
i=`expr $i - 1`
echo "SUMMARY"
echo "UP fails: $UP_FAIL/$i"
echo "OFF fails: $OFF_FAIL/$i"
echo "READ fails: $PACKET_FAIL/$i"
