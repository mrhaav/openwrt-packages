#!/bin/sh
#
# AT commands for Huawei E3372h-320 modem
# 2025-11-20 by mrhaav
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
    [ "$atc_debug" -gt 1 ] && echo JSON: $(json_dump)
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

hua_ip_hex2dec () {
    local hex_ip=$(echo $1 | grep -o '[0-9a-fA-F]\+$')
    local dec_ip=null
    local x

    [ ${#hex_ip} -eq 8 ] && {
        for x in 6 4 2 0
        do
            [ $x -eq 6 ] && {
                dec_ip=$(printf '%d' 0x${hex_ip:$x:2})
            } || {
                dec_ip=$dec_ip'.'$(printf '%d' 0x${hex_ip:$x:2})
            }
        done
    }

    echo $dec_ip
}

full_apn () {
    local apn=$1
    local rest

    rest=$(echo ${apn#*'.mnc'})
    rest=${#rest}
    rest=$((rest+4))
    [ $rest -lt ${#apn} ] && apn=${apn:: -$rest}

    echo $apn
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
    local sms_rx_folder=/var/sms/rx
    local OK_received=0
    local connected=0
    local devname devpath atOut conStatus manufactor model fw rssi
    local firstASCII URCline URCcommand URCvalue x status rat new_rat cops_format operator plmn used_apn sms_index sms_pdu
    local dual_stack
    local device apn pdp pincode auth username password delay atc_debug v6dns_ra $PROTO_DEFAULT_OPTIONS

    json_get_vars device ifname apn pdp pincode auth username password delay atc_debug v6dns_ra $PROTO_DEFAULT_OPTIONS

    local custom_at=$(uci get network.${interface}.custom_at 2>/dev/null)

    mkdir -p $sms_rx_folder

    [ -z "$delay" ] && delay=15
    [ ! -f /var/modem.status -a "$delay" -ge 1 ] && {
        echo 'Modem boot delay '$delay's'
        sleep "$delay"
    }

    [ -z $ifname ] && {
        devname=$(basename $device)
        case "$devname" in
            *ttyACM*)
                devpath="$(readlink -f /sys/class/tty/$devname/device)"
                [ -n "$devpath" ] && ifname="$(ls  $devpath/../*/net/)" 2>/dev/null
                ;;
            *ttyUSB*)
                devpath="$(readlink -f /sys/class/tty/$devname/device)"
                [ -n "$devpath" ] && ifname="$(ls $devpath/../../*/net/)"  2>/dev/null
                ;;
        esac
    }
    [ -n "$ifname" ] || {
        proto_notify_error "$interface" NO_IFACE
        proto_set_available "$interface" 0
        proto_block_restart "$interface"
        return 1
    }

    zone="$(fw3 -q network "$interface" 2>/dev/null)"
    echo 0 > /var/modem.status
    echo Initiate modem with interface $ifname

# Set error codes to verbose
    atOut=$(COMMAND='AT+CMEE=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    while [ "$atOut" != 'OK' ]
    do
        echo 'Modem not ready yet: '$atOut
        sleep 1
        atOut=$(COMMAND='AT+CMEE=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
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

# Enable flightmode
    atOut=$(COMMAND='AT+CFUN=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    conStatus=offline

# Get modem manufactor and model
    atOut=$(COMMAND='ATI' gcom -d "$device" -s /etc/gcom/getrun_at.gcom)
    manufactor=$(echo "$atOut" | grep Manufacturer | awk -F ':' '{print $2}' | sed -e 's/\r//g')
    manufactor=${manufactor:1}
    model=$(echo "$atOut" | grep Model | awk -F ':' '{print $2}' | sed -e 's/\r//g')
    model=${model:1}
    fw=$(echo "$atOut" | grep Revision | awk -F ':' '{print $2}' | sed -e 's/\r//g')
    fw=${fw:1}
    [ "$atc_debug" -gt 1 ] && {
        echo $manufactor
        echo $model
        echo $fw
    }
    if [[ "$manufactor" = 'Huawei'* ]] && [ "$model" = E3372h-320 ]
    then
        :
    else
        echo 'Modem: '$manufactor' - '$model
        echo 'Warning! This is optimized for: Huawei Technologies Co.,Ltd. - E3372h-320'
    fi
    echo Configure modem

# Enable unsolicted indications
    atOut=$(COMMAND='AT^CURC=1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# URC +CREG, +CGREG and +CEREG
    atOut=$(COMMAND='AT+CREG=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CGREG=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CEREG=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Configure PDPcontext, profile 0 and 1
    atOut=$(COMMAND='AT+CGDCONT=0,"'$pdp'","'$apn'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CGDCONT=1,"'$pdp'","'$apn'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Configure authentication, user and password, profile 0 and 1
    atOut=$(COMMAND='AT^AUTHDATA=0,'$auth',,"'$username'","'$password'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT^AUTHDATA=1,'$auth',,"'$username'","'$password'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# SMS config
    atOut=$(COMMAND='AT+CMGF=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CSCS="GSM"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CNMI=2,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut

# Disable flightmode
    echo Activate modem
    COMMAND='AT+CFUN=1' gcom -d "$device" -s /etc/gcom/at.gcom
    
    while read URCline
    do
        firstASCII=$(printf "%d" \'${URCline::1})
        if [ ${firstASCII} != 13 ] && [ ${firstASCII} != 32 ] && [ ${#URCline} -gt 1 ]
        then
            URCcommand=$(echo $URCline | awk -F ':' '{print $1}')
            URCcommand=$(echo $URCcommand | sed -e 's/[\r\n]//g')
            x=${#URCcommand}
            x=$(($x+1))
            URCvalue=${URCline:x}
            [ "${URCvalue::1}" = ' ' ] && URCvalue=${URCvalue:1}
            URCvalue=$(echo $URCvalue | sed -e 's/"//g' | sed -e 's/[\r\n]//g')

            case $URCcommand in

                +CEREG|+CGREG )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    status=$(echo $URCvalue | awk -F ',' '{print $1}')
                    [ $URCcommand = '+CGREG' -a "$(echo $URCvalue | awk -F ',' '{print $4}')" = '7' ] && status=7
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
                                [ "$atc_debug" -ge 1 ] && echo 'Cell change'$(CxREG $URCvalue)
                                [ "$new_rat" != "$rat" -a -n "$rat" ] && {
                                    echo 'RATchange: '$rat' -> '$new_rat
                                    rat=$new_rat
                                }
                            else
                                echo ' '$conStatus' -> registered - home network'$(CxREG $URCvalue)
                                conStatus='registered'
                            fi
                            ;;
                        2 )
                            echo ' '$conStatus' -> searching'$(CxREG $URCvalue)
                            conStatus='searching'
                            ;;
                        3 )
                            echo 'Registration denied, '$(CxREG $URCvalue)
                            [ $connected -eq 0 ] && {
                                proto_notify_error "$interface" REG_DENIED
                                proto_block_restart "$interface"
                                return 1
                            }
                            ;;
                        4 )
                            echo 'Unknown'
                            ;;
                        5 )
                            if [ "$conStatus" = 'registered' ]
                            then
                                [ "$atc_debug" -ge 1 ] && echo 'Cell change, '$(CxREG $URCvalue)
                                [ "$new_rat" != "$rat" -a -n "$rat" ] && {
                                    echo RATchange: $rat -> $new_rat
                                    rat=$new_rat
                                }
                            else
                                echo ' '$conStatus' -> registered - roaming'$(CxREG $URCvalue)
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
                        echo Activate session
                        OK_received=1
                    }
                    ;;
                
                ^NWTIME )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    [ $connected -eq 0 ] && {
                        COMMAND='AT+COPS=3,0;+COPS?;+COPS=3,2;+COPS?' gcom -d "$device" -s /etc/gcom/at.gcom
                    } || {
                        echo 'Re-activate session'
                        COMMAND='AT^NDISSTATQRY?' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    ;;

                ^NDISSTAT )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    stat=$(echo $URCvalue | awk -F ',' '{print $1}')
                    err_code=$(echo $URCvalue | awk -F ',' '{print $2}')
                    pdp_type=$(echo $URCvalue | awk -F ',' '{print $4}')
                    [ "$stat" -eq 1 ] && {
                        connected=1
                        proto_init_update "$ifname" 1
                        proto_set_keep 1
                        proto_add_data
                        json_add_string "modem" "${model}"
                        proto_close_data
                        proto_send_update "$interface"
                        OK_received=2
                        COMMAND='AT^NDISSTATQRY?' gcom -d "$device" -s /etc/gcom/at.gcom
                    }

                    [ "$stat" -eq 0 ] && {
                        echo Session disconnected
                        proto_init_update "$ifname" 0
                        proto_send_update "$interface"
                        connected=2
                    }
                    ;;

                ^NDISSTATQRY )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    dual_stack=''
                    stat=$(echo $URCvalue | awk -F ',' '{print $1}')
                    pdp_type=$(echo $URCvalue | awk -F ',' '{print $4}')
                    [ "$stat" -eq 1 ] && {
                        dual_stack=$pdp_type
                    }
                    stat=$(echo $URCvalue | awk -F ',' '{print $5}')
                    pdp_type=$(echo $URCvalue | awk -F ',' '{print $8}')
                    [ "$stat" -eq 1 ] && {
                        dual_stack=$dual_stack$pdp_type
                    }
                    [ $connected -eq 2 -a -z $dual_stack ] && {
                        [ $pdp = 'IPV4V6' ] && OK_received=1 || OK_received=4
                    }
                    ;;

                ^DHCP )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    v4address=$(hua_ip_hex2dec $(echo $URCvalue | awk -F ',' '{print $1}'))
                    v4netmask=$(subnet_calc $v4address)
                    v4gateway=$(echo $v4netmask | awk -F ' ' '{print $2}')
                    v4netmask=$(echo $v4netmask | awk -F ' ' '{print $1}')
                    v4dns1=$(hua_ip_hex2dec $(echo $URCvalue | awk -F ',' '{print $5}'))
                    v4dns2=$(hua_ip_hex2dec $(echo $URCvalue | awk -F ',' '{print $6}'))
                    update_IPv4
                    ;;

                ^DHCPV6 )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    v6dns1=$(echo $URCvalue | awk -F ',' '{print $5}')
                    v6dns2=$(echo $URCvalue | awk -F ',' '{print $6}')
                    OK_received=0
                    update_DHCPv6
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
                    [ "$atc_debug" -gt 1 ] && echo $URCline
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
                    [ $OK_received -eq 4 ] && {
                        COMMAND='AT+CGDCONT=1,"'$pdp'","'$apn'"' gcom -d "$device" -s /etc/gcom/at.gcom
                        OK_received=1
                    }
                    [ $OK_received -eq 3 ] && {
                        COMMAND='AT^DHCPV6?' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ $OK_received -eq 2 ] && {
                        [[ "$dual_stack" = *'IPV4'* ]] && {
                            [[ "$dual_stack" = *'IPV6'* ]] && OK_received=3 || OK_received=0
                            COMMAND='AT^DHCP?' gcom -d "$device" -s /etc/gcom/at.gcom
                        }
                        [ $dual_stack = 'IPV6' ] && COMMAND='AT^DHCPV6?' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ $OK_received -eq 1 ] && {
                        COMMAND='AT^NDISDUP=1,1' gcom -d "$device" -s /etc/gcom/at.gcom
                        OK_received=0
                    }
                    ;;

                ^RSSI|^CERSSI|^ANLEVEL|^HCSQ|^LCACELLURC )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
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
    echo $interface is disconnected
    proto_init_update "*" 0
    proto_send_update "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
    add_protocol atc
}
