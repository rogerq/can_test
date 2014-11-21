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
# DCAN1 registers
DCAN1_CTL=0x4AE3C000
DCAN1_ES=0x4AE3C004
DCAN1_ERRC=0x4AE3C008
DCAN1_BTR=0x4AE3C00C

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
# wakeup0->dcan1_rx
# devmem2 $CTRL_CORE_PAD_WAKEUP0 w 0x00010001

# RAMINIT send start pulse. CTRL_CORE_CONTROL_IO_2
devmem2 $CTRL_CORE_CONTROL_IO_2 w 0x8
devmem2 $CTRL_CORE_CONTROL_IO_2 w 0x0

# ---DCAN initialize---
#set INIT to 1
devmem2 $DCAN1_CTL w 0x1
#set CCE to 1
devmem2 $DCAN1_CTL w 0x41
#check if INIT is 1
VAL=$(devmem2 $DCAN1_CTL | awk '/Value at address/{print $6}')
if [ $VAL != '0x41' ] ; then
	echo "CAN set init failed: DCAN1_CTL = $VAL"
fi
# bitrate - 250Kb/s
devmem2 $DCAN1_BTR w 0x1C04
#clear CCE and INIT
devmem2 $DCAN1_CTL w 0x0
#check if INIT is 0
VAL=$(devmem2 $DCAN1_CTL | awk '/Value at address/{print $6}')
if [ $VAL != '0x0' ] ; then
	echo "CAN clear init failed: DCAN1_CTL = $VAL"
fi
}

function disable_dcan1 {
# RAMINIT clear done and start. CTRL_CORE_CONTROL_IO_2
VAL=$(devmem2 $CTRL_CORE_CONTROL_IO_2 | awk '/Value at address/{print $6}')
# writing a 1 to DONE clears it. so write back what we read.
devmem2 $CTRL_CORE_CONTROL_IO_2 w $VAL
devmem2 $CTRL_CORE_CONTROL_IO_2 w 0x0

#set INIT to 1
devmem2 $DCAN1_CTL w 0x1
#check if INIT is 1
VAL=$(devmem2 $DCAN1_CTL | awk '/Value at address/{print $6}')
if [ $VAL != '0x1' ] ; then
	echo "CAN set init failed: DCAN1_CTL = $VAL"
fi

# wakeup0->off
# devmem2 $CTRL_CORE_PAD_WAKEUP0 w 0x0000000F
# Disable DCAN1 module
devmem2 $CM_WKUPAON_DCAN1_CLKCTRL w 0x0
sleep 1
}


# Enable and disable DCAN1 in a loop
ITERS=5
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
