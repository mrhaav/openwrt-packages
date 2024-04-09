#!/bin/sh
#
# AT commands for Mikrotek R11-LTE6 modem
# by mrhaav 2023-08-27
#


[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

update_statv4 () {
	json_init
	json_add_string name "${interface}_4"
	json_add_string ifname "@$interface"
	json_add_string proto "static"
	json_add_array ipaddr
	json_add_string "" "${v4address}/${v4netmask}"
	json_close_array
	json_add_string gateway "$v4gateway"
	[ "$peerdns" = 0 ] || {
		json_add_array dns
		json_add_string "" "$v4dns1"
		json_add_string "" "$v4dns2"
		json_close_array
	}
	[ -n "$zone" ] && json_add_string zone "$zone"
	json_close_object
	[ "$atc_debug" -ge 1 ] && echo JSON: $(json_dump)
	ubus call network add_dynamic "$(json_dump)"
}

update_dhcpv6 () {
	json_init
	json_add_string name "${interface}_6"
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
		7|9 )
			rat_nb=LTE ;;
	esac
	echo $rat_nb
}


proto_atc_init_config() {
	no_device=1
	available=1
	proto_config_add_string "device:device"
	proto_config_add_string "apn"
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
	local CGCONTRDP=false
	local CESQ=false
	local devname devpath hwaddr ip4addr ip4mask dns1 dns2 defroute lladdr
	local rat new_rat name ifname proto extendprefix
	local device ifname apn pdp pincode auth username password delay atc_debug $PROTO_DEFAULT_OPTIONS
	json_get_vars device ifname apn pdp pincode auth username password delay atc_debug $PROTO_DEFAULT_OPTIONS

	[ -n "$delay" ] && sleep "$delay" || sleep 1

	[ -z $ifname ] && {
		devname=$(basename $device)
		case "$devname" in
			*ttyACM*)
				devpath="$(readlink -f /sys/class/tty/$devname/device)"
				ifname="$(ls -1 $devpath/../*/net/)"  > /dev/null 2>&1
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
			if [ -z $PINcode ]
			then
				echo PINcode required but missing
				proto_notify_error "$interface" PINmissing
				proto_block_restart "$interface"
				return 1
			fi
			atOut=$(COMMAND="AT+CPIN=${PINcode}" gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep 'CME ERROR:')
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

# Set operator name to long format
	atOut=$(COMMAND='AT+COPS=3,0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut

# Enable flightmode
	atOut=$(COMMAND='AT+CFUN=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
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
	[ "$manufactor" = 'MikroTik' -a "$model" = 'R11e-LTE6' ] || {
		echo Wrong script. This is optimized for: $manufactor, $model
		proto_notify_error "$interface" MODEM
		proto_set_available "$interface" 0
	}

# URC, +CGREG and +CEREG 
	atOut=$(COMMAND='AT+CREG=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	atOut=$(COMMAND='AT$CREG=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	atOut=$(COMMAND='AT+CGREG=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	atOut=$(COMMAND='AT+CEREG=2' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	
# CGEREG, for URCcode +CGEV
	atOut=$(COMMAND='AT+CGEREP=2,1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut

# Set DHCP lease time to 0
	atOut=$(COMMAND='AT+ZDHCPLEASE=0' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut

# Configure default PDPcontext
	atOut=$(COMMAND='AT+ZGDCONT=5,"'$pdp'","'$apn'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	atOut=$(COMMAND='AT+ZGPCOAUTH=5,"'$username'","'$password'",'$auth gcom -d "$device" -s /etc/gcom/run_at.gcom)
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
			URCvalue=$(echo $URCvalue | sed -e 's/[\r\n]//g')
			case $URCcommand in

				+CEREG )
					[ "$atc_debug" = 2 ] && echo $URCline
					[ ${#URCvalue} -gt 6 ] && {
						new_rat=$(echo $URCvalue | awk -F ',' '{print $4}')
						new_rat=$(nb_rat $new_rat)
					}
					URCvalue=$(echo $URCvalue | awk -F ',' '{print $1}')
					case $URCvalue in
						0 )
							if [ $conStatus = connected ]
							then
								echo ' '$conStatus' -> notSearching, disconnected'
							else
								echo ' '$conStatus' -> notSearching'
							fi
							conStatus=notSearching
							;;
						1 )
							[ $conStatus != 'registered' ] && {
								echo ' '$conStatus' -> registered - home network'
								conStatus=registered
							} || {
								[ "$new_rat" != "$rat" ] && {
									echo 'RATchange: '$rat' -> '$new_rat
									rat=$new_rat
								}
							}
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
							[ $conStatus != 'registered' ] && {
								echo ' '$conStatus' -> registered - roaming'
								conStatus=registered
							} || {
								[ "$new_rat" != "$rat" ] && {
									echo RATchange: $rat -> $new_rat
									rat=$new_rat
								}
							}
							;;
					esac
					;;
				
				+COPS )
					[ "$atc_debug" -ge 1 ] && echo $URCline
					operator=$(echo $URCvalue | awk -F ',' '{print $3}' | sed -e 's/"//g')
					rat=$(echo $URCvalue | awk -F ',' '{print $4}')
					rat=$(nb_rat $rat)
					echo 'Registered to '$operator' on '$rat
					echo Activate session
					COMMAND='AT+ZGACT=1,5' gcom -d "$device" -s /etc/gcom/at.gcom
					;;
				
				+CGEV )
					[ "$atc_debug" -ge 1 ] && echo $URCline
					case $URCvalue in
						'EPS PDN DEACT'*|'NW PDN DEACT'* )
							echo Session disconnected
							release_interface
							;;

						'EPS PDN ACT'*|'NW PDN ACT'* )
							atOut=$(COMMAND='AT+COPS?' gcom -d "$device" -s /etc/gcom/at.gcom)
							;;
					esac
					;;

				+ZGIPDNS )
					[ "$atc_debug" -ge 1 ] && echo $URCline
					URCvalue=$(echo $URCvalue | sed -e 's/"//g')
					pdp_type=$(echo $URCvalue | awk -F ',' '{print $2}')
					proto_init_update "$ifname" 1
					proto_set_keep 1
					proto_add_data
					json_add_string "modem" "${manufactor}_${model}"
					proto_close_data
					proto_send_update "$interface"
					echo Connected PDP type: $pdp_type
					[ "$pdp_type" = 'IP' -o "$pdp_type" = 'IPV4V6' ] && {
						v4address=$(echo $URCvalue | awk -F ',' '{print $3}')
						v4netmask=$(subnet_calc $v4address)
						v4gateway=$(echo $v4netmask | awk -F ' ' '{print $2}')
						v4netmask=$(echo $v4netmask | awk -F ' ' '{print $1}')
						v4dns1=$(echo $URCvalue | awk -F ',' '{print $5}')
						v4dns2=$(echo $URCvalue | awk -F ',' '{print $6}')
						update_statv4
					}
					[ "$pdp_type" = 'IPV6' -o "$pdp_type" = 'IPV4V6' ] && update_dhcpv6
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
