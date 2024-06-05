#!/bin/sh
#
# AT commands for MikroTik R11e-LTE modem
# 2024-06-05 by mrhaav
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
    [ -n "$zone" ] && json_add_string zone "$zone"
    json_close_object
    [ "$atc_debug" -ge 1 ] && echo JSON: $(json_dump)
    ubus call network add_dynamic "$(json_dump)"
}

release_interface () {
    proto_init_update "$ifname" 0
    proto_send_update "$interface"
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
    esac
    echo $rat_nb
}

CxREG () {
    local reg_string=$1
    local lac_tac g_cell_id rat

    [ ${#reg_string} -gt 6 ] && {
        lac_tac=$(echo $reg_string | awk -F ',' '{print $2}')
        g_cell_id=$(echo $reg_string | awk -F ',' '{print $3}')
        rat=$(echo $reg_string | awk -F ',' '{print $4}')
        [ "$rat" -le 6 ] && {
            reg_string='RNCid: '$(printf '%d' 0x${g_cell_id:: -4})' LAC: '$(printf '%d' 0x$lac_tac)' CellId: '$(printf '%d' 0x${g_cell_id: -4})
        }
        [ "$rat" -eq 7 -o "$rat" -eq 13 ] && {
            reg_string='TAC: '$(printf '%d' 0x$lac_tac)' eNodeB: '$(printf '%d' 0x${g_cell_id:: -2})'-'$(printf '%d' 0x${g_cell_id: -2})
        }
    }
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
    proto_config_add_defaults
}

proto_atc_setup () {
    local interface="$1"
    local OK_received=0
    local devname devpath interface conStatus plmn operator pdp_type
    local new_rat status p_cid atOut manufactor model URCline URCcommand URCvalue
    local device ifname apn pdp pincode auth username password delay atc_debug $PROTO_DEFAULT_OPTIONS
    json_get_vars device ifname apn pdp pincode auth username password delay atc_debug $PROTO_DEFAULT_OPTIONS

    [ -n "$delay" ] && sleep "$delay" || sleep 1

    [ -z $ifname ] && {
        devname=$(basename $device)
        case "$devname" in
            *ttyACM*)
                devpath="$(readlink -f /sys/class/tty/$devname/device)"
                ifname="$(ls $devpath/../*/net/)" > /dev/null 2>&1
                ;;
        esac
    }
    [ -n "$ifname" ] || {
        echo "No interface could be found"
        proto_notify_error "$interface" NO_IFACE
        proto_block_restart "$interface"
        return 1
    }

    zone="$(fw3 -q network "$interface" 2>/dev/null)"

    echo Initiate modem with interface $ifname

# Set error codes to verbose
    atOut=$(COMMAND='AT+CMEE=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    while [ $atOut != 'OK' ]
    do
        echo 'Modem not ready yet: '$atOut
        sleep 1
        atOut=$(COMMAND='AT+CMEE=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    done
    
# Check SIMcard and PIN status
    atOut=$(COMMAND="AT+CPIN?" gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep CPIN: | awk -F ' ' '{print $2 $3}' | sed -e 's/[\r\n]//g')
    while [ -z $atOut ]
    do
        atOut=$(COMMAND="AT+CPIN?" gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep CPIN: | awk -F ' ' '{print $2 $3}' | sed -e 's/[\r\n]//g')
    done
    case $atOut in
        READY )
            echo SIMcard ready
            ;;
        SIMPIN )
            if [ -z $pincode ]
            then
                echo PINcode required but missing
                proto_notify_error "$interface" PINmissing
                proto_block_restart "$interface"
                return 1
            fi
            atOut=$(COMMAND="AT+CPIN=${pincode}" gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep 'CME ERROR:')
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

# Set operator name in numeric format
        atOut=$(COMMAND='AT+COPS=3,2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
        [ "$atOut" != 'OK' ] && echo $atOut
    
# Enable flightmode
        atOut=$(COMMAND='AT+CFUN=4' gcom -d "$device" -s /etc/gcom/run_at.gcom)
        [ "$atOut" != 'OK' ] && echo $atOut
        conStatus=offline
    echo Configure modem

# Get modem manufactor and model
    atOut=$(COMMAND='AT+CGMI' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep CGMI: | awk -F ':' '{print $2}')
    manufactor=$(echo $atOut | sed -e 's/"//g')
    manufactor=$(echo $manufactor | sed -e 's/\r//g')
        atOut=$(COMMAND='AT+CGMM' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep CGMM: | awk -F ':' '{print $2}')
        model=$(echo $atOut | sed -e 's/"//g')
        model=$(echo $model | sed -e 's/\r//g')
    [ "$manufactor" = MikroTik -a "$model" = R11e-LTE ] || {
        echo Wrong script. This is optimized for: $manufactor, $model
        proto_notify_error "$interface" MODEM
        proto_set_available "$interface" 0
    }

# URC, +CGREG and +CEREG 
    atOut=$(COMMAND='AT+CREG=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CGREG=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT+CEREG=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    
# CGEREG, for URCcode +CGEV
    atOut=$(COMMAND='AT+CGEREP=2,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    
# Configure default PDPcontext
    atOut=$(COMMAND='AT*CGDFLT=0,"'$pdp'","'$apn'",,,,,,,,,,1,0,,,,,,,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    atOut=$(COMMAND='AT*CGDFAUTH=0,'$auth',"'$username'","'$password'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
    [ "$atOut" != 'OK' ] && echo $atOut
    
# Disable flightmode
    echo Activate modem
    COMMAND='AT+CFUN=1' gcom -d "$device" -s /etc/gcom/at.gcom
    
    while read URCline
    do
        firstASCII=$(printf "%d" \'${URCline::1})
        if [ ${firstASCII} != 13 ] && [ ${firstASCII} != 32 ]
        then
            URCcommand=$(echo $URCline | awk -F ':' '{print $1}')
            URCcommand=$(echo $URCcommand | sed -e 's/[\r\n]//g')
            x=${#URCcommand}
            x=$(($x+2))
            URCvalue=${URCline:x}
            URCvalue=$(echo $URCvalue | sed -e 's/"//g' | sed -e 's/[\r\n]//g')
            case $URCcommand in

                +CGREG|+CEREG )
                    [ "$atc_debug" = 2 ] && echo $URCline
                    [ ${#URCvalue} -gt 6 ] && {
                        new_rat=$(echo $URCvalue | awk -F ',' '{print $4}')
                        new_rat=$(nb_rat $new_rat)
                    }
                    status=$(echo $URCvalue | awk -F ',' '{print $1}')
                    case $status in
                        0 )
                            echo ' '$conStatus' -> notRegistered, '$(CxREG $URCvalue)
                            conStatus=notRegistered
                            ;;
                        1 )
                            if [ "$conStatus" = 'registered' ]
                            then
                                [ "$atc_debug" -ge 1 ] && echo 'Cell change, '$(CxREG $URCvalue)
                                [ "$new_rat" != "$rat" ] && {
                                    echo 'RATchange: '$rat' -> '$new_rat
                                    rat=$new_rat
                                }
                            else
                                echo ' '$conStatus' -> registered - home network, '$(CxREG $URCvalue)
                                conStatus='registered'
                            fi
                            ;;
                        2 )
                            echo ' '$conStatus' -> searching'
                            conStatus=searching
                            ;;
                        3 )
                            echo 'Registration denied'
                            proto_notify_error "$interface" REG_DENIED
                            proto_block_restart "$interface"
                            return 1
                            ;;
                        4 )
                            echo 'Unknown'
                            ;;
                        5 )
                            if [ "$conStatus" = 'registered' ]
                            then
                                [ "$atc_debug" -ge 1 ] && echo 'Cell change, '$(CxREG $URCvalue)
                                [ "$new_rat" != "$rat" ] && {
                                    echo 'RATchange: '$rat' -> '$new_rat
                                    rat=$new_rat
                                }
                            else
                                echo ' '$conStatus' -> registered - roaming, '$(CxREG $URCvalue)
                                conStatus='registered'
                            fi
                            ;;
                    esac
                    ;;
                
                +COPS )
                    [ "$atc_debug" -gt 1 ] && echo $URCline
                    cops_format=$(echo $URCvalue | awk -F ',' '{print $2}')
                    [ $cops_format -eq 2 ] && {
                        plmn=$(echo $URCvalue | awk -F ',' '{print $3}' | sed -e 's/"//g')
                        OK_received=1
                    }
                    [ $cops_format -eq 0 ] && {
                        operator=$(echo $URCvalue | awk -F ',' '{print $3}' | sed -e 's/"//g')
                        rat=$(echo $URCvalue | awk -F ',' '{print $4}')
                        rat=$(nb_rat $rat)
                        echo 'Registered to '$operator' PLMN:'$plmn' on '$rat
                        echo Activate session
                        OK_received=3
                    }
                    ;;
                
                +CGEV )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    case $URCvalue in
                        'EPS PDN DEACT'*|'NW PDN DEACT'* )
                            echo Session disconnected
                            release_interface
                            ;;

                        'EPS PDN ACT'*|'NW PDN ACT'* )
                            COMMAND='AT+COPS?' gcom -d "$device" -s /etc/gcom/at.gcom
                            ;;
                    esac
                    ;;

                +CGDCONT )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    URCvalue=$(echo $URCvalue | sed -e 's/"//g')
                    p_cid=$(echo $URCvalue | awk -F ',' '{print $1}')
                    pdp_type=$(echo $URCvalue | awk -F ',' '{print $2}')
                    proto_init_update "$ifname" 1
                    proto_set_keep 1
                    proto_add_data
                    json_add_string "modem" "${manufactor}_${model}"
                    proto_close_data
                    proto_send_update "$interface"
                    OK_received=4
                    ;;

                +CGCONTRDP )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    URCvalue=$(echo $URCvalue | sed -e 's/"//g')
                    v4address=$(echo $URCvalue | awk -F ',' '{print $4}')
                    [ "$pdp_type" = 'IP' -o "$pdp_type" = 'IPV4V6' ] && {
                        v4netmask=$(subnet_calc $v4address)
                        v4gateway=$(echo $v4netmask | awk -F ' ' '{print $2}')
                        v4netmask=$(echo $v4netmask | awk -F ' ' '{print $1}')
                        v4dns1=$(echo $URCvalue | awk -F ',' '{print $7}')
                        v4dns2=$(echo $URCvalue | awk -F ',' '{print $8}')
                        update_IPv4
                    }
                    [ "$pdp_type" = 'IPV6' -o "$pdp_type" = 'IPV4V6' ] && update_DHCPv6
                    ;;

                OK )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    [ $OK_received -eq 4 ] && {
                        OK_received=10
                        COMMAND='AT+CGCONTRDP='$p_cid gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ $OK_received -eq 3 ] && {
                        OK_received=4
                        COMMAND='AT+CGDCONT?' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ $OK_received -eq 2 ] && {
                        COMMAND='AT+COPS?' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    [ $OK_received -eq 1 ] && {
                        OK_received=2
                        COMMAND='AT+COPS=3,0' gcom -d "$device" -s /etc/gcom/at.gcom
                    }
                    ;;
                * )
                    [ "$atc_debug" -ge 1 ] && echo $URCline
                    ;;
            esac
        fi
    done < ${device}
}


proto_atc_teardown() {
    local interface="$1"
    echo $interface is disconnected
    proto_init_update "*" 0
    proto_send_update "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
    add_protocol atc
}
