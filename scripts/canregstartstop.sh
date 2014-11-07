#!/bin/sh

#
# Enable and disable DCAN1 module
#

# pinmux addresses
CTRL_CORE_PAD_DCAN1_TX=0x4a0037d0
CTRL_CORE_PAD_DCAN1_RX=0x4a0037d4
CTRL_CORE_PAD_WAKEUP0=0x4a003818
# register addresses
CTRL_CORE_CONTROL_IO_2=0x4A002558
CM_WKUPAON_DCAN1_CLKCTRL=0x4AE07888

# ---configure pinmuxes---
# dcan1_tx
devmem2 $CTRL_CORE_PAD_DCAN1_TX w 0x00010000
# wakeup0->dcan1_rx
devmem2 $CTRL_CORE_PAD_WAKEUP0 w 0x00010001
# dcan1_rx->off
devmem2 $CTRL_CORE_PAD_DCAN1_RX w 0x0000000F

function enable_dcan1 {
# Enable DCAN1 module. CM_WKUPAON_DCAN1_CLKCTRL
devmem2 $CM_WKUPAON_DCAN1_CLKCTRL w 0x2

# RAMINIT send start pulse. CTRL_CORE_CONTROL_IO_2
devmem2 $CTRL_CORE_CONTROL_IO_2 w 0x8
devmem2 $CTRL_CORE_CONTROL_IO_2 w 0x0

VAL=$(devmem2 $CTRL_CORE_CONTROL_IO_2 | awk '/Value at address/{print $6}')
echo after enable iocontrol=$VAL
}

function disable_dcan1 {
# RAMINIT clear done and start. CTRL_CORE_CONTROL_IO_2
VAL=$(devmem2 $CTRL_CORE_CONTROL_IO_2 | awk '/Value at address/{print $6}')
# writing a 1 to DONE clears it. so write back what we read.
devmem2 $CTRL_CORE_CONTROL_IO_2 w $VAL
devmem2 $CTRL_CORE_CONTROL_IO_2 w 0x0
VAL=$(devmem2 $CTRL_CORE_CONTROL_IO_2 | awk '/Value at address/{print $6}')
echo after disable iocontrol=$VAL

# Disable DCAN1 module
devmem2 $CM_WKUPAON_DCAN1_CLKCTRL w 0x0
}


# Enable and disable DCAN1 in a loop
ITERS=10
RAMINIT_FAIL=0
OFF_FAIL=0
for (( i = 1 ; i <= $ITERS ; i++ ))
do
	echo "test $i"
	enable_dcan1
	VAL=$(devmem2 $CTRL_CORE_CONTROL_IO_2 | awk '/Value at address/{print $6}')
	if [ $VAL != '0x2' ] ; then
		echo $CANDEV "RAMINIT failed" $i - VAL:$VAL
		RAMINIT_FAIL=`expr $RAMINIT_FAIL + 1`
	fi

	disable_dcan1
	VAL=$(devmem2 $CM_WKUPAON_DCAN1_CLKCTRL | awk '/Value at address/{print $6}')
	if [ $VAL != '0x30000' ] ; then
		echo $CANDEV "off failed" $i - VAL:$VAL
		OFF_FAIL=`expr $OFF_FAIL + 1`
	fi
	echo "RAMINIT fails: $RAMINIT_FAIL/$i OFF fails: $OFF_FAIL/$i"
done
i=`expr $i - 1`
echo "SUMMARY"
echo "RAMINIT fails: $RAMINIT_FAIL/$i"
echo "OFF fails: $OFF_FAIL/$i"
