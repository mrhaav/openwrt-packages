#!/bin/sh
# 
# mrhaav 2021-05-16
# Huawei ME909s-120 modem
# SIM PIN should be deactivated
# ^SYSCFGEX: "00",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF

. /usr/share/libubox/jshn.sh

modemUSBport=$(dmesg | grep 'GSM modem' | grep 'usb ' | awk 'NR==1' | awk -F 'ttyUSB' '{print $NF}')
DEV='/dev/ttyUSB'$modemUSBport
logger -t modem Device $DEV

uci set network.wwan.ttyDEV=$DEV
uci commit network

APN=$(uci get network.wwan.apn)
pdpType=$(uci get network.wwan.pdp_type)
checkTimer=$(uci get network.wwan.check_timer)

[ -z "$checkTimer" ] && checkTimer=600


sysinfoex () {
    atOut=$(COMMAND="AT^sysinfoex" gcom -d $DEV -s /etc/gcom/getrun_at.gcom | grep SYSINFOEX | awk -F ' ' '{print $2}')
    while [ -z $atOut ]
    do
        atOut=$(COMMAND="AT^sysinfoex" gcom -d $DEV -s /etc/gcom/getrun_at.gcom | grep SYSINFOEX | awk -F ' ' '{print $2}')
    done
    srv_status=$(echo $atOut | awk -F ',' '{print $1}')
    srv_domain=$(echo $atOut | awk -F ',' '{print $2}')
    sim_state=$(echo $atOut | awk -F ',' '{print $4}')
    case $srv_status in
        0 )
            SRVstatus="No services. " ;;
        1 )
            SRVstatus="Restricted services. " ;;
        2 )
            SRVstatus="Valid services. " ;;
        3 )
            SRVstatus="Restricted regional services. " ;;
        4 )
            SRVstatus="Power saving or hibernate state. " ;;
        * )
            SRVstatus="Service status: "$srv_status". " ;;
    esac
    case $srv_domain in
        0 )
            SRVstatus=$SRVstatus"No services. " ;;
        1 )
            SRVstatus=$SRVstatus"CS service only. " ;;
        2 )
            SRVstatus=$SRVstatus"PS service only. " ;;
        3 )
            SRVstatus=$SRVstatus"PS+CS services. " ;;
        4 )
            SRVstatus=$SRVstatus"Not registered to CS or PS; searching now. " ;;
        * )
            SRVstatus=$SRVstatus"Domiain status: "$srv_domain". " ;;
    esac
    case $sim_state in
        0 )
            SRVstatus=$SRVstatus"Invalid SIM card. " ;;
        1 )
            SRVstatus=$SRVstatus"Valid SIM card. " ;;
        2 )
            SRVstatus=$SRVstatus"Invalid SIM card in CS. " ;;
        3 )
            SRVstatus=$SRVstatus"Invalid SIM card in PS. " ;;
        4 )
            SRVstatus=$SRVstatus"Invalid SIM card in PS and CS. " ;;
        255 )
            SRVstatus=$SRVstatus"No SIM card is found. " ;;
        * )
            SRVstatus=$SRVstatus"SIM status: "$sim_state". " ;;
    esac
    logger -t modem $SRVstatus
    
    if [ $srv_status$srv_domain$sim_state -ne 231 ] 
    then
        logger -t modem -p 3 $srv_status$srv_domain$sim_state
        echo "$srv_status$srv_domain$sim_state" > /var/modem.status
        exit 1
    fi
}


# Set error codes to verbose
atOut=$(COMMAND="AT+CMEE=2" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | awk 'NR==2' | sed -e 's/[\r\n]//g')
while [ "$atOut" != 'OK' ]
do
    logger -t modem Not ready yet.
    atOut=$(COMMAND="AT+CMEE=2" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | awk 'NR==2' | sed -e 's/[\r\n]//g')
done

# Check SIMcard and PIN status
atOut=$(COMMAND="AT+CPIN?" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | awk 'NR==2' | awk -F : '{print $2}' | sed -e 's/[\r\n]//g' | sed 's/^ *//g')
if [ "$atOut" = 'READY' ]
# Initiate modem
then
#   Flight mode on
    atOut=$(COMMAND="AT+CFUN=0" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
#   Disable unsolicted indications
    atOut=$(COMMAND="AT^CURC=0" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
#   Modem manufacturer information
    atOut=$(COMMAND="AT+CGMI" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | awk 'NR==2')
    logger -t modem $atOut
#   Modem model information
    atOut=$(COMMAND="AT+CGMM" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | awk 'NR==2')
    logger -t modem $atOut
#   Configure PDPcontext
    atOut=$(COMMAND="AT+CGDCONT=0,\"$pdpType\",\"$APN\"" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
    atOut=$(COMMAND="AT+CGDCONT=1,\"$pdpType\",\"$APN\"" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
#   Flight mode off
    atOut=$(COMMAND="AT+CFUN=1" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
    sleep 1
#   Check service status
    sysinfoex
#   Check operator
    atOut=$(COMMAND="AT+COPS?" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | awk 'NR==2' | awk -F , '{print $3}' | sed -e 's/\"//g')
    logger -t modem Connected to $atOut
#   Activate NDIS application
    atOut=$(COMMAND="AT^NDISDUP=1,1" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
    echo OK > /var/modem.status
else
    logger -t modem -p 3 $atOut
    echo $atOut > /var/modem.status
    exit 1
fi
sleep 30

# Check ping every checkTimer
while true
do
# Compare modem IP with interface IP 
    json_init
    json_load $(ubus -S call network.interface.wwan status)
    json_select ipv4_address
    json_select 1
    json_get_var wwan_ip address
    modem_ip=$(COMMAND="at+cgpaddr=1" gcom -d $DEV -s /etc/gcom/getrun_at.gcom | grep CGPADDR | awk -F , '{print $2}' | sed -e 's/"//g' | sed -e 's/[\r\n]//g')
    while [ -z $modem_ip ]
    do
        modem_ip=$(COMMAND="at+cgpaddr=1" gcom -d $DEV -s /etc/gcom/getrun_at.gcom | grep CGPADDR | awk -F , '{print $2}' | sed -e 's/"//g' | sed -e 's/[\r\n]//g')
    done 
    if [ "$modem_ip" != "$wwan_ip" ]
    then
	logger -t modem Modem IP $modem_ip, wwan IP $wwan_ip. Release old IP from modem and lease a new.
        PIDwwan0=$(cat /var/run/udhcpc-wwan0.pid)
        kill -SIGUSR2 $PIDwwan0
        kill -SIGUSR1 $PIDwwan0
        sleep 2
    fi
    pingWWAN=$(ping 8.8.8.8 -c 4 -W 1 -I wwan0 | grep packets | awk '{print $7 }' | sed s/%//g)
    if [ "$pingWWAN" = 100 ] || [ -z "$pingWWAN" ]
    then
        logger -t modem -p 3 Restart modem
        logger -t modem Modem: $modem_ip wwan: $wwan_ip
        sysinfoex
#       Flight mode on
        atOut=$(COMMAND="AT+CFUN=0" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
        sleep 1
#       Flight mode off
        atOut=$(COMMAND="AT+CFUN=1" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
        sleep 1
#       Activate NDIS application
        atOut=$(COMMAND="AT^NDISDUP=1,1" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
#       Check service status
        sysinfoex

    fi
    sleep $checkTimer
done
