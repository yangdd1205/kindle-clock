#!/bin/sh

PWD=$(pwd)
LOG="/mnt/us/clock.log"

wait_wlan() {
  return `lipc-get-prop com.lab126.wifid cmState | grep CONNECTED | wc -l`
}

eips -c
eips 10 10 "Preparing Clock..."
ntpdate -s us.pool.ntp.org
### Prepare Kindle, shutdown framework etc.
echo "------------------------------------------------------------------------" >> $LOG
echo "`date '+%Y-%m-%d_%H:%M:%S'`: Starting up, killing framework et. al." >> $LOG
#/sbin/initctl stop framework
lipc-set-prop com.lab126.pillow disableEnablePillow disable

if [ -f /usr/sbin/wancontrol ]
then
    lipc-set-prop com.lab126.wan stopWan 1
    wancontrol wanoff
fi

eips -c
eips 10 10 "Starting Clock"

echo "`date '+%Y-%m-%d_%H:%M:%S'`: Entering main loop..."

while true; do

    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Top of loop"
	### Disable Screensaver
	lipc-set-prop com.lab126.powerd preventScreenSaver 1

	### Enable WIFI
#	lipc-set-prop com.lab126.cmd wirelessEnable 1
#	while wait_wlan; do
#	  sleep 1
#	done
#	echo `date '+%Y-%m-%d_%H:%M:%S'`: WIFI enabled! >> $LOG

    echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor


    # ntpdate -s us.pool.ntp.org

    BAT=$(gasgauge-info -s | sed s/%//)
	echo `date '+%Y-%m-%d_%H:%M:%S'`: battery level: $BAT >> $LOG

    ### Display time
	rm -f $PWD/kindle-clock.png
    export LD_LIBRARY_PATH=$PWD/lib
    TIME=$(date '+%H:%M')
    DATE=$(date '+%A, %-d. %B %Y')

    sed -e "s/#TIME/${TIME}/" \
        -e "s/#BAT/${BAT}/" \
        -e "s/#DATE/${DATE}/" $PWD/clock-preprocess.svg > $PWD/clock-script-output.svg
    time $PWD/bin/rsvg-convert --background-color=white -o out.png clock-script-output.svg
    time $PWD/bin/pngcrush -l 1 -q -c 0 out.png kindle-clock.png
    eips -g $PWD/kindle-clock.png

    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Display updated"


    ### Enable CPU Powersave
	echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor


	### Disable WIFI
#	lipc-set-prop com.lab126.cmd wirelessEnable 0


    ### Set Wakeuptimer
	#echo 0 > /sys/class/rtc/rtc1/wakealarm
	#echo ${WAKEUP_TIME} > /sys/class/rtc/rtc1/wakealarm
    NOW=$(date +%s)
    let WAKEUP_TIME="((($NOW + 59)/60)*60)"
    let SLEEP_SECS=$WAKEUP_TIME-$NOW
    echo `date '+%Y-%m-%d_%H:%M:%S'`: Wake-up time set for  `date -d @${WAKEUP_TIME}`
    echo `date '+%Y-%m-%d_%H:%M:%S'`: Sleeping for $SLEEP_SECS...
    rtcwake -d /dev/rtc1 -m no -s $SLEEP_SECS

	### Go into Suspend to Memory (STR)
	echo `date '+%Y-%m-%d_%H:%M:%S'`: Sleeping now...
	echo "mem" > /sys/power/state
done
