#!/bin/sh
#
# atc rssi daemon, runs every 60sec
# by mrhaav 2025-03-17
#

interface=$(uci show network | grep proto | grep atc | awk -F . '{print $2}')
device=$(uci get network.${interface}.device)

while true
do
    COMMAND='AT+CESQ' gcom -d "$device" -s /etc/gcom/at.gcom
	
	sleep 60
done
