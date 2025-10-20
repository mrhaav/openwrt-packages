#!/bin/sh
#
# AT commands for Fibocom L850-GL and L860-GL modems
# 2025-09-06 by mrhaav
#


[ -n "$INCLUDE_ONLY" ] || {
    . /lib/functions.sh
    . ../netifd-proto.sh
    init_proto "$@"
}

update_IPv4 () {
    proto_init_update "$ifname" 1
    proto_set_keep 1
    proto_add_ipv4_address "$v4address" "$v4netmask"
    proto_add_ipv4_route "$v4gateway" "128"
    [ "$defaultroute" = 0 ] || proto_add_ipv4_route "0.0.0.0" 0 "$v4gateway"
    [ "$peerdns" = 0 ] || {
        proto_add_dns_server "$v4dns1"
        proto_add_dns_server "$v4dns2"
    }
    [ -n "$zone" ] && {
        proto_add_data
        json_add_string zone "$zone"
        proto_close_data
    }
    proto_send_update "$interface"
}

update_DHCPv6 () {
    json_init
    json_add_string name "${interface}6"
    json_add_string ifname "@$interface"
    json_add_string proto "dhcpv6"
    proto_add_dynamic_defaults
    json_add_string extendprefix 1
    [ "$peerdns" = 0 ] || {
        json_add_array dns
        json_add_string "" "$v6dns1"
        json_add_string "" "$v6dns2"
        json_close_array
    }
    [ -n "$zone" ] && json_add_string zone "$zone"
    json_close_object
    [ "$atc_debug" -ge 1 ] && echo JSON: $(json_dump)
    ubus call network add_dynamic "$(json_dump)"
}

subnet_calc () {
    local IPaddr=$1
    local A B C D 
    local x y netaddr res subnet gateway

    A=$(echo $IPaddr | awk -F '.' '{print $1}')
    B=$(echo $IPaddr | awk -F '.' '{print $2}')
    C=$(echo $IPaddr | awk -F '.' '{print $3}')
    D=$(echo $IPaddr | awk -F '.' '{print $4}')

    x=1
    y=4
    netaddr=$((y-1))
    res=$((D%y))

    while [ $res -eq 0 ] || [ $res -eq $netaddr ]
    do
        x=$((x+1))
        y=$((y*2))
        netaddr=$((y-1))
        res=$((D%y))
    done

    subnet=$((31-x))
    gateway=$((D/y))
    [ $res -eq 1 ] && gateway=$((gateway*y+2)) || gateway=$((gateway*y+1))
    echo $subnet $A.$B.$C.$gateway
}

nb_rat () {
    local rat_nb=$1
    case $rat_nb in
        0|1|3 )
            rat_nb=GSM ;;
        2|4|5|6 )
            rat_nb=WCDMA ;;
        7 )
            rat_nb=LTE ;;
        11 )
            rat_nb=NR ;;
        13 )
            rat_nb=LTE-ENDC
    esac
    echo $rat_nb
}

CxREG () {
    local reg_string=$1
    local lac_tac g_cell_id rat reject_cause

    if [ ${#reg_string} -gt 4 ]
    then
        lac_tac=$(echo $reg_string | awk -F ',' '{print $2}')
        g_cell_id=$(echo $reg_string | awk -F ',' '{print $3}')
        rat=$(echo $reg_string | awk -F ',' '{print $4}')
        [ -n "$rat" ] && rat=$(nb_rat $rat) || reg_string=''
        reject_cause=$(echo $reg_string | awk -F ',' '{print $6}')
        [ -z "$reject_cause" ] && reject_cause=0
        [ "$rat" = 'WCDMA' ] && {
            reg_string=', RNCid:'$(printf '%d' 0x${g_cell_id:: -4})' LAC:'$(printf '%d' 0x$lac_tac)' CellId:'$(printf '%d' 0x${g_cell_id: -4})
        }
        [ "${rat::3}" = 'LTE' ] && {
            reg_string=', TAC:'$(printf '%d' 0x$lac_tac)' eNodeB:'$(printf '%d' 0x${g_cell_id:: -2})'-'$(printf '%d' 0x${g_cell_id: -2})
        }
        [ "$reject_cause" -gt 0 ] && reg_string=$reg_string' - Reject cause: '$reject_cause
        [ "$reject_cause" -eq 0 -a "${reg_string::1}" = '0' ] && reg_string=''
    else
        reg_string=''
    fi
    echo $reg_string
}

full_apn () {
    local apn=$1
    local rest

    apn=$(echo $apn | awk '{print tolower($0)}')
    rest=$(echo ${apn#*'.mnc'})
    rest=${#rest}
    rest=$((rest+4))
    [ $rest -lt ${#apn} ] && apn=${apn:: -$rest}

    echo $apn
}

proto_atc_init_config() {
    no_device=1
    available=1
    proto_config_add_string "device:device"
    proto_config_add_string "apn"
    proto_config_add_string "pincode"
    proto_config_add_string "pdp"
    proto_config_add_string "auth"
    proto_config_add_string "username"
    proto_config_add_string "password"
    proto_config_add_string "atc_debug"
    proto_config_add_string "delay"
    proto_config_add_string "v6dns_ra"
    proto_config_add_defaults
}

proto_atc_setup () {
    local interface="$1"
    local OK_received=0
    local nw_disconnect=0
    local devname devpath atOut conStatus manufactor model fw rssi
    local firstASCII URCline URCcommand URCvalue x status rat new_rat cops_format operator plmn used_apn
    local v6address hwaddr h devname
    local device ifname apn pdp pincode auth username password delay atc_debug v6dns_ra $PROTO_DEFAULT_OPTIONS

    json_get_vars device ifname apn pdp pincode auth username password delay atc_debug v6dns_ra $PROTO_DEFAULT_OPTIONS

    local custom_at=$(uci get network.${interface}.custom_at 2>/dev/null)

    mkdir -p /var/sms/rx

# Boot LED
    /usr/bin/modem_led boot 2>/dev/null

    [ -z "$delay" ] && delay=15
    [ ! -f /var/modem.status ] && {
        echo 'Modem boot delay '$delay's'
        sleep "$delay"
    }

    devname=$(basename $device)
    case "$devname" in
        *ttyACM*)
            devpath="$(readlink -f /sys/class/tty/$devname/device)"
            hwaddr="$(ls -1 $devpath/../*/net/*/*address*)"
            for h in $hwaddr
            do
                if [ "$(cat ${h})" = "00:00:11:12:13:14" ]
                then
                    ifname=$(echo ${h} | awk -F [\/] '{print $(NF-1)}')
                fi
            done
        ;;
    esac

    [ -n "$ifname" ] || {
        echo "No interface could be found"
        proto_notify_error "$interface" NO_IFACE
        proto_block_restart "$interface"
        return 1
    }

    zone="$(fw3 -q network "$interface" 2>/dev/null)"
    echo 0 > /var/modem.status
    echo Initiate modem with interface $ifname

# Set error codes to verbose
    atOut=$(COMMAND='AT+CMEE=2' gcom -d "$device" -s /etc/gcom/run_at.gcom 2>&1)
    while [ "$atOut" != 'OK' ]
    do
        echo 'Modem not ready yet'
        [ "$atc_debug" -gt 1 ] && {
            echo $device
            [ -n "$(echo "$atOut" | grep 'Error @')" ] && atOut=$(echo "$atOut" | grep 'Error @')
            echo $atOut
        }
        sleep 1
        atOut=$(COMMAND='AT+CMEE=2' gcom -d "$device" -s /etc/gcom/run_at.gcom 2>&1)
    done

# Check SIMcard and PIN status
    atOut=$(COMMAND='AT+CPIN?' gcom -d "$device" -s /etc/gcom/getrun_at.gcom)
    if [ -n "$(echo "$atOut" | grep 'CPIN:')" ]
    then
        atOut=$(echo "$atOut" | grep 'CPIN:' | awk -F ':' '{print $2}' | sed -e 's/[\r\n]//g')
        [ "${atOut::1}" = ' ' ] && atOut=${atOut:1}
    elif [ -n "$(echo "$atOut" | grep 'CME ERROR:')" ]
    then
        atOut=$(echo "$atOut" | grep 'CME ERROR:' | awk -F ':' '{print $2}' | sed -e 's/[\r\n]//g')
        [ "${atOut::1}" = ' ' ] && atOut=${atOut:1}
        echo $atOut
        proto_notify_error "$interface" "$atOut"
        proto_block_restart "$interface"
        return 1
    else
        echo 'Can not read SIMcard'
        proto_notify_error "$interface" SIMreadfailure
        proto_block_restart "$interface"
        return 1
    fi
    case $atOut in
        READY )
            echo SIMcard ready
            ;;
        'SIM PIN' )
            if [ -z "$pincode" ]
            then
                echo PINcode required but missing
                proto_notify_error "$interface" PINmissing
                proto_block_restart "$interface"
                return 1
            fi
            atOut=$(COMMAND='AT+CPIN="'$pincode'"' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep 'CME ERROR:')
            if [ -n "$atOut" ]
            then
                echo PINcode error: ${atOut:11}
                proto_notify_error "$interface" PINerror
                proto_block_restart "$interface"
                return 1
            fi
            echo PINcode verified
            ;;
        * )
            echo SIMcard error: $atOut
            proto_notify_error "$interface" PINerror
            proto_block_restart "$interface"
            return 1
            ;;
    esac

# Config LED
    /usr/bin/modem_led config 2>/dev/null

# Enable flightmode
    atOut=$(COMMAND='AT+CFUN=4' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    conStatus=offline
    echo Configure modem

# Get modem manufactor and model
    manufactor=$(COMMAND='AT+CGMI' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep -Ev "^(AT\+CGMI\r|\r|OK\r)" | sed -e 's/"//g' | sed -e 's/\r//g')
    [[ "$manufactor" = '+CGMI:'* ]] && {
        manufactor=${manufactor:6}
        [ "${manufactor::1}" = ' ' ] && manufactor=${manufactor:1}
    }
    model=$(COMMAND='AT+CGMM' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep -Ev "^(AT\+CGMM\r|\r|OK\r)" | sed -e 's/"//g' | sed -e 's/\r//g')
    [[ "$model" = '+CGMM:'* ]] && {
        model=${model:6}
        [ "${model::1}" = ' ' ] && model=${model:1}
    }
    [ "$atc_debug" -gt 1 ] && {
        fw=$(COMMAND='AT+CGMR' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep -Ev "^(AT\+CGMR\r|\r|OK\r)" | sed -e 's/"//g' | sed -e 's/\r//g')
        [[ "$fw" = '+CGMR:'* ]] && {
            fw=${fw:6}
            [ "${fw::1}" = ' ' ] && fw=${fw:1}
        }
        echo $manufactor
        echo $model
        echo $fw
    }
    if [ -n "$(echo "$manufactor" | grep 'Fibocom')" ] && [ -n "$(echo "$model" | grep 'L8[5|6]0')" ]
    then
        :
    else
        echo 'Wrong script. This is optimized for: Fibocom, L850 or L860 LTE Module'
        echo "$manufactor"
        echo "$model"
        proto_notify_error "$interface" MODEM
        proto_block_restart "$interface"
        return 1
    fi

# URC, CREG, CGREG and CEREG
    atOut=$(COMMAND='AT+CREG=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CGREG=3' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CEREG=3' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# CGEREG, for URCcode +CGEV
    atOut=$(COMMAND='AT+CGEREP=2,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Configure PDPcontext, profile 0
    atOut=$(COMMAND='AT+CGDCONT=0,"'$pdp'","'$apn'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+XGAUTH=0,'$auth',"'$username'","'$password'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Enable dynamic DNS
    atOut=$(COMMAND='AT+XDNS=0,1;+XDNS=0,2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Set IPv6 format
    atOut=$(COMMAND='AT+CGPIAF=1,1,0,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# SMS config
    atOut=$(COMMAND='AT+CMGF=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CSCS="GSM"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CNMI=2,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

#  Enable signal strength reporting
    atOut=$(COMMAND='AT+XCESQ=1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+XCESQRC=1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Disable camped cell info
    atOut=$(COMMAND='AT+XCCINFO=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Custom AT-commands
    [ $(echo $custom_at | wc -w) -gt 0 ] && {
        echo 'Running custom AT-commands'
        for at_command in $custom_at
        do
            [ $(echo ${at_command::2} | awk '{print toupper($0)}') = 'AT' ] && {
                echo ' '$at_command
                atOut=$(COMMAND=$at_command gcom -d "$device" -s /etc/gcom/getrun_at.gcom)
                lines=$(echo "$atOut" | wc -l)
                x=1
                while [ $x -le $lines ]
                do
                    at_line=$(echo "$atOut" | sed -n $x'p' | sed -e 's/[\r\n]//g')
                    [ $(echo ${#at_line}) -gt 0 -a "$at_line" != "$at_command" ] && echo ' '$at_line
                    x=$((x+1))
                done
            } || {
                echo 'Start custom AT-command with "AT", '$at_command
            }
        done
    }

# Disable flightmode
    echo Activate modem
    COMMAND='AT+CFUN=1' gcom -d "$device" -s /etc/gcom/at.gcom

# Searching LED
    /usr/bin/modem_led searching 2>/dev/null

    while read URCline
    do
        firstASCII=$(printf "%d" \'${URCline::1})
        if [ ${firstASCII} != 13 ] && [ ${firstASCII} != 32 ]
        then
            URCcommand=$(echo $URCline | awk -F ':' '{print $1}')
            URCcommand=$(echo $URCcommand | sed -e 's/[\r\n]//g')
            x=${#URCcommand}
            x=$(($x+1))
            URCvalue=${URCline:x}
            URCvalue=$(echo $URCvalue | sed -e 's/"//g' | sed -e 's/[\r\n]//g')
            [ "${URCvalue::1}" = ' ' ] && URCvalue=${URCvalue:1}

            case $URCcommand in
                +CGREG|+CEREG )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    status=$(echo $URCvalue | awk -F ',' '{print $1}')
                    [ ${#URCvalue} -gt 6 ] && {
                        new_rat=$(echo $URCvalue | awk -F ',' '{print $4}')
                        new_rat=$(nb_rat $new_rat)
                    }
                    case $status in
                        0 )
                            echo ' '$conStatus' -> notRegistered'$(CxREG $URCvalue)
                            conStatus='notRegistered'
                            ;;
                        1 )
                            if [ "$conStatus" = 'registered' ]
                            then
                                [ "$new_rat" != "$rat" -a -n "$rat" ] && {
                                    echo 'RATchange: '$rat' -> '$new_rat
                                    rat=$new_rat
# Connected LED
                                    /usr/bin/modem_led connected_$new_rat 2>/dev/null
                                }
                                [ "$atc_debug" -ge 1 ] && echo 'Cell change'$(CxREG $URCvalue)
                            else
                                echo ' '$conStatus' -> registered - home network'$(CxREG $URCvalue)
                                rat=$new_rat
                                conStatus='registered'
                            fi
                            ;;
                        2 )
                            echo ' '$conStatus' -> searching '$(CxREG $URCvalue)
                            conStatus='searching'
                            ;;
                        3 )
                            echo 'Registration denied'
                            [ $nw_disconnect -eq 0 ] && {
                                proto_notify_error "$interface" REG_DENIED
                                proto_block_restart "$interface"
                                return 1
                            }
                            ;;
                        4 )
                            echo ' '$conStatus' -> unknown'
                            conStatus='unknown'
                            ;;
                        5 )
                            if [ "$conStatus" = 'registered' ]
                            then
                                [ "$new_rat" != "$rat" -a -n "$rat" ] && {
                                    echo RATchange: $rat -> $new_rat
                                    rat=$new_rat
# Connected LED
                                    /usr/bin/modem_led connected_$new_rat 2>/dev/null
                                }
                                [ "$atc_debug" -ge 1 ] && echo 'Cell change'$(CxREG $URCvalue)
                            else
                                echo ' '$conStatus' -> registered - roaming'$(CxREG $URCvalue)
                                rat=$new_rat
                                conStatus='registered'
                            fi
                            ;;
                        esac
                    ;;

                +COPS )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    cops_format=$(echo $URCvalue | awk -F ',' '{print $2}')
                    [ $cops_format -eq 0 ] && {
                        operator=$(echo $URCvalue | awk -F ',' '{print $3}' | sed -e 's/"//g')
                    }
                    [ $cops_format -eq 2 ] && {
                        plmn=$(echo $URCvalue | awk -F ',' '{print $3}' | sed -e 's/"//g')
                        rat=$(echo $URCvalue | awk -F ',' '{print $4}')
                        rat=$(nb_rat $rat)
                        echo 'Registered to '$operator' PLMN:'$plmn' on '$rat
                        echo 'Activate session'
                        OK_received=1
                    }
                    ;;

                +CGEV )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    case $URCvalue in
                        'NW DETACH' )
                            nw_disconnect=1
                            ;;
                        'ME PDN DEACT 0'|'NW PDN DEACT 0' )
                            echo 'Session disconnected by the network'
# Searching LED
                            /usr/bin/modem_led searching 2>/dev/null
                            proto_init_update "$ifname" 0
                            proto_send_update "$interface"
                            ;;
                        'ME PDN ACT 0' )
                            [ $nw_disconnect -eq 0 ] && {
                                nw_disconnect=2
                                COMMAND='AT+COPS=3,0;+COPS?;+COPS=3,2;+COPS?' gcom -d "$device" -s /etc/gcom/at.gcom
                            } || {
                                nw_disconnect=2
                                echo 'Re-activate session'
                                COMMAND='AT+CGCONTRDP=0' gcom -d "$device" -s /etc/gcom/at.gcom
                                OK_received=2
                            }
                            ;;
                    esac
                    ;;

                +CGCONTRDP )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    [ -z "$used_apn" ] && {
                        used_apn=$(echo $URCvalue | awk -F ',' '{print $3}')
                        used_apn=$(full_apn $used_apn)
                        [ "$apn" != $used_apn ] && echo 'Using network default APN: '$used_apn
                    }
                    IPv6=$(echo $URCvalue | grep -a ':')
                    if [ -z "$IPv6" ]
                    then
                        v4address=$(echo $URCvalue | awk -F ',' '{print $4}' | awk -F '.' '{print $1"."$2"."$3"."$4}')
                        v4netmask=$(subnet_calc $v4address)
                        v4gateway=$(echo $v4netmask | awk -F ' ' '{print $2}')
                        v4netmask=$(echo $v4netmask | awk -F ' ' '{print $1}')
                        v4dns1=$(echo $URCvalue | awk -F ',' '{print $6}')
                        v4dns2=$(echo $URCvalue | awk -F ',' '{print $7}')
                    else
                        v6address=$(echo $URCvalue | awk -F ',' '{print $4}')
                        v6dns1=$(echo $URCvalue | awk -F ',' '{print $6}')
                        v6dns2=$(echo $URCvalue | awk -F ',' '{print $7}')
                    fi
                    ;;

                CONNECT )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
# Connected LED
                    /usr/bin/modem_led connected_$new_rat 2>/dev/null
                    proto_init_update "$ifname" 1
                    proto_set_keep 1
                    proto_add_data
                    json_add_string "modem" "${model}"
                    proto_close_data
                    proto_send_update "$interface"
                    ip link set dev $ifname arp off
                    [ -n "$v4address" ] && update_IPv4
                    [ -n "$v6address" ] && update_DHCPv6
                    ;;

                +XCESQI )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    rssi=$(echo $URCvalue | awk -F ',' '{print $6}')
                    [ $rssi -ne 255 ] 2>/dev/null && {
                        rssi=$(($rssi*100/97))
                    } || {
                        rssi=$(echo $URCvalue | awk -F ',' '{print $3}')
                        [ $rssi -ne 255 ] 2>/dev/null && rssi=$(($rssi*100/96)) || rssi=256
                    }
                    /usr/bin/modem_led rssi $rssi 2>/dev/null
                    ;;

                +CMTI )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    sms_index=$(echo $URCvalue | awk -F ',' '{print $2}')
                    COMMAND='AT+CMGR='$sms_index gcom -d "$device" -s /etc/gcom/at.gcom
                    ;;

                +CMGR )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    OK_received=11
                    ;;

                +CMGS )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    echo 'SMS successfully sent'
                    ;;

                OK )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    [ $OK_received -eq 12 ] && {
                        /usr/bin/atc_rx_pdu_sms $sms_pdu 2> /dev/null
                        [ $sms_index -gt 1 ] && {
                            sms_index=$((sms_index-1))
                            COMMAND='AT+CMGR='$sms_index gcom -d "$device" -s /etc/gcom/at.gcom
                        } || {
                            OK_received=0
                        }
                    }
                    [ $OK_received -eq 11 ] && {
                        COMMAND='AT+CMGD='$sms_index gcom -d "$device" -s /etc/gcom/at.gcom
                        OK_received=12
                    }
                    [ $OK_received -eq 3 ] && {
                        COMMAND='AT+CGDATA="M-RAW_IP",0' gcom -d "$device" -s /etc/gcom/at.gcom
                        OK_received=10
                    }
                    [ $OK_received -eq 2 ] && {
                        COMMAND='AT+XDATACHANNEL=1,1,"/USBCDC/0","/USBHS/NCM/0",2,0' gcom -d "$device" -s /etc/gcom/at.gcom
                        OK_received=3
                    }
                    [ $OK_received -eq 1 ] && {
                        COMMAND='AT+CGCONTRDP=0' gcom -d "$device" -s /etc/gcom/at.gcom
                        OK_received=2
                    }
                    ;;

                * )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    [ $OK_received -eq 11 ] && {
                        sms_pdu=$URCline
                        echo 'SMS received'
                        [ "$atc_debug" -gt 1 ] && echo $sms_pdu >> /var/sms/pdus 2> /dev/null
                    }
                    ;;
            esac
        fi
	done < ${device}
}


proto_atc_teardown() {
    local interface="$1"
    local device=$(uci -q get network.$interface.device)
    echo $interface is disconnected
    /usr/bin/modem_led off 2> /dev/null
    atOut=$(COMMAND='AT+XDATACHANNEL=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    atOut=$(COMMAND='AT+CGDATA=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    proto_init_update "*" 0
    proto_send_update "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
    add_protocol atc
}
