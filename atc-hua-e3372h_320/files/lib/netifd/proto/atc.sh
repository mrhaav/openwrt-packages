#!/bin/sh
#
# Modem Huawei E3372h-320
# mrhaav 2023-09-13
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
update_dhcpv4 () {
	json_init
	json_add_string name "${interface}_4"
	json_add_string ifname "@$interface"
	json_add_string proto "dhcp"
	proto_add_dynamic_defaults
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
	local CGCONTRDP=false
	local CESQ=false
	local devname devpath hwaddr ip4addr ip4mask dns1 dns2 defroute lladdr
	local rat new_rat name ifname proto extendprefix
	local device ifname apn pdp pincode auth username password delay atc_debug $PROTO_DEFAULT_OPTIONS
	json_get_vars device ifname apn pdp pincode auth username password delay atc_debug $PROTO_DEFAULT_OPTIONS

	mkdir -p /var/3gpp

	[ -n "$delay" ] && sleep "$delay" || sleep 1

	[ -z $ifname ] && {
		devname=$(basename $device)
		case "$devname" in
			*ttyACM*)
				devpath="$(readlink -f /sys/class/tty/$devname/device)"
				ifname="$(ls  $devpath/../*/net/)"  > /dev/null 2>&1
				;;
			*ttyUSB*)
				devpath="$(readlink -f /sys/class/tty/$devname/device)"
				ifname="$(ls $devpath/../../*/net/)"  > /dev/null 2>&1
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
		atOut=$(COMMAND="AT+CMEE=2" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	done

# Check SIMcard and PIN status
	atOut=$(COMMAND='AT+CPIN?' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep 'CPIN:\|+CME')
	while [ -z "$atOut" ]
	do
		atOut=$(COMMAND="AT+CPIN?" gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep 'CPIN:\|+CME')
	done
	[[ "$atOut" = '+CPIN:'* ]] && {
		atOut=$(echo $atOut | awk -F ' ' '{print $2 $3}' | sed -e 's/[\r\n]//g')
	} || {
		atOut=$(echo $atOut | awk -F ':' '{print $2}' | sed -e 's/[\r\n]//g')
	}
	case $atOut in
		READY )
			echo 'SIMcard ready'
			;;
		SIMPIN )
			if [ -z "$pincode" ]
			then
				echo 'PINcode required but missing'
				proto_notify_error "$interface" PIN_ERR
				proto_block_restart "$interface"
				return 1
			fi
			atOut=$(COMMAND="AT+CPIN=${pincode}" gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep 'CME ERROR:')
			if [ -n "$atOut" ]
			then
				echo 'PINcode error: '${atOut:11}
				proto_notify_error "$interface" PIN_ERR
				proto_block_restart "$interface"
				return 1
			fi
			echo 'PINcode verified'
			;;
		* )
			echo 'SIMcard error:'$atOut
			proto_notify_error "$interface" SIM_ERR
			proto_block_restart "$interface"
			return 1
			;;
	esac


# Enable flight mode
	atOut=$(COMMAND="AT+CFUN=0" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	conStatus=offline
	echo Configure modem

# Get IMSI
	imsi=$(COMMAND='AT+CIMI' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | awk 'NR==2')
	imsi=$(echo $imsi | sed -e 's/\r//g')

# Get ICCID
	atOut=$(COMMAND='AT^ICCID?' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | grep 'ICCID:')
	iccid=$(echo $atOut | awk -F ' ' '{print $2}')

# Get IMEI
	imei=$(COMMAND='AT+CGSN' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | awk 'NR==2')
	imei=$(echo $imei | sed -e 's/\r//g')

# Get modem manufactor
	atOut=$(COMMAND='AT+CGMI' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | awk 'NR==2')
	manufactor=$(echo $atOut | sed -e 's/"//g')
	manufactor=$(echo $manufactor | sed -e 's/\r//g')

# Get modem model
	atOut=$(COMMAND='AT+CGMM' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | awk 'NR==2')
	model=$(echo "$atOut" | sed -e 's/"//g')
	model=$(echo $model | sed -e 's/\r//g')

# Get modem firmware
	fw=$(COMMAND='AT+CGMR' gcom -d "$device" -s /etc/gcom/getrun_at.gcom | awk 'NR==2')
	fw=$(echo $fw | sed -e 's/\r//g')

	json_init
	json_add_string imsi "${imsi}"
	json_add_string iccid "${iccid}"
	json_add_string imei "${imei}"
	json_add_string manufactor "${manufactor}"
	json_add_string model "${model}"
	json_add_string firmware "${fw}"
	json_close_object
	echo $(json_dump) > /var/3gpp/modem

# Check script
	MANUFATOR='Huawei Technologies Co.,Ltd.'
	MODEL='E3372h-320'
	[ "$manufactor" = "$MANUFATOR" -a "$model" = "$MODEL" ] || {
		echo Wrong script. This is optimized for: $MANUFATOR, $MODEL
		echo Your modem: $manufactor, $model
		proto_notify_error "$interface" MODEM
		proto_block_restart "$interface"
		return 1
	}

# Set operator name in long format
	atOut=$(COMMAND="AT+COPS=3,0" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut

# URC
# Enable unsolicted indications
	atOut=$(COMMAND="AT^CURC=1" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut

# CREG, CGREG, CEREG
# 0 Disable network registration unsolicited result code
# 1 Enable network registration unsolicited result code
# 2 Enable network registration and location information unsolicited result code <stat>[,<lac>,<ci>[,<AcT>]]
	atOut=$(COMMAND="AT+CREG=0" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	atOut=$(COMMAND="AT+CGREG=2" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	atOut=$(COMMAND="AT+CEREG=2" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut

# CGEREG, URCcode +cgev
#	atOut=$(COMMAND="AT+CGEREP=2,1" gcom -d "$device" -s /etc/gcom/run_at.gcom)
#	[ "$atOut" != 'OK' ] && echo $atOut


# Configure PDPcontext
	atOut=$(COMMAND='AT+CGDCONT=0,"'$pdp'","'$apn'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut
	atOut=$(COMMAND='AT+CGDCONT=1,"'$pdp'","'$apn'"' gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut


# SMS in text format
	atOut=$(COMMAND="AT+CMGF=1" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut

# Enable New SMS Indications to TE
	atOut=$(COMMAND="AT+CNMI=0,1" gcom -d "$device" -s /etc/gcom/run_at.gcom)
	[ "$atOut" != 'OK' ] && echo $atOut

# Enable cell change URC
#        atOut=$(COMMAND='AT^HFREQINFO=1' gcom -d "$device" -s /etc/gcom/run_at.gcom)
#        [ "$atOut" != 'OK' ] && echo $atOut

# Disable flight mode
	echo Activate modem
	atOut=$(COMMAND="AT+CFUN=1" gcom -d "$device" -s /etc/gcom/at.gcom)


	while read URCline
	do
		firstASCII=$(printf "%d" \'${URCline::1})
		if [ ${firstASCII} != 13 ] && [ ${firstASCII} != 32 ]
		then
			URCcommand=$(echo $URCline | awk -F ':' '{print $1}')
			URCvalue=$(echo $URCline | awk -F ':' '{print $2}')
			URCvalue=$(echo $URCvalue | sed -e 's/[\r\n]//g')
			[ "${URCvalue::1}" = ' ' ] && URCvalue=${URCvalue:1}
			URCvalue=$(echo $URCvalue | sed -e 's/"//g')

			case $URCcommand in

				+CGREG )
					[ "$atc_debug" -eq 2 ] && echo $URCline
					REGvalue=$(echo $URCvalue | awk -F ',' '{print $1}')
					case $REGvalue in
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
							[ $conStatus != 'registered' -a ${conStatus::9} != 'connected' ] && {
								echo ' '$conStatus' -> registered - home network'
								conStatus=registered
								COMMAND="AT+COPS?" gcom -d "$device" -s /etc/gcom/at.gcom
							}
							tac=$(echo $URCvalue | awk -F ',' '{print $2}')
							tac=$(printf "%d" 0x$tac)
							scell=$(echo $URCvalue | awk -F ',' '{print $3}')
							scell=$(printf "%d" 0x${scell:: -2})'-'$(printf "%d" 0x${scell: -2})
							[ ${conStatus::9} = 'connected' ] && {
								COMMAND='AT^HFREQINFO?' gcom -d "$device" -s /etc/gcom/at.gcom
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
								COMMAND="AT+COPS?" gcom -d "$device" -s /etc/gcom/at.gcom
							}
							tac=$(echo $URCvalue | awk -F ',' '{print $2}')
							tac=$(printf "%d" 0x$tac)
							scell=$(echo $URCvalue | awk -F ',' '{print $3}')
							scell=$(printf "%d" 0x${scell:: -2})'-'$(printf "%d" 0x${scell: -2})
							[ ${conStatus::9} = 'connected' ] && {
								COMMAND='AT^HFREQINFO?' gcom -d "$device" -s /etc/gcom/at.gcom
							}
							;;
					esac
					;;
	
				+COPS )
					[ "$atc_debug" -ge 1 ] && echo $URCline
					operator=$(echo $URCvalue | awk -F ',' '{print $3}' | sed -e 's/"//g')
					rat=$(echo $URCvalue | awk -F ',' '{print $4}')
					case $rat in
						0|1|3 )
							rat=GSM ;;
						2|4|5|6 )
							rat=WCDMA ;;
						7 )
							rat=LTE ;;
					esac
					echo 'Registered to '$operator' on '$rat
					echo 'Activte session'
					COMMAND="AT^NDISDUP=1,1" gcom -d "$device" -s /etc/gcom/at.gcom
					;;
	
				^NDISSTAT )
					[ "$atc_debug" -ge 1 ] && echo $URCline
					stat=$(echo $URCvalue | awk -F ',' '{print $1}')
					err_code=$(echo $URCvalue | awk -F ',' '{print $2}')
					PDP_type=$(echo $URCvalue | awk -F ',' '{print $4}'| sed -e 's/"//g')
					if [ "$stat" = 1 ]
					then
						echo ' connected with' $PDP_type
						proto_init_update "$ifname" 1
						proto_set_keep 1
						proto_add_data
						json_add_string "modem" "${manufactor}_${model}"
						proto_close_data
						proto_send_update "$interface"
						update_dhcpv4
#						update_dhcpv6
						[ ${conStatus::9} = connected ] && conStatus=${conStatus}${PDP_type:2:2} || conStatus=connected${PDP_type:2:2}
						connected=$(date '+%Y-%m-%d %H:%M:%S')
						json_init
						json_load_file /var/3gpp/modem
						json_add_string connected "${connected}"
						json_close_object
						echo $(json_dump) > /var/3gpp/modem
						json_init
						json_add_string operator "${operator}"
						json_add_string plmn "${plmn}"
						json_add_string rat "$rat"
						json_close_object
						[ "$atc_debug" -eq 2 ] && echo $(json_dump)
						echo $(json_dump) > /var/3gpp/cell
						COMMAND='AT^HFREQINFO?' gcom -d "$device" -s /etc/gcom/at.gcom
					elif [ "$stat" = 0 ]
					then
						if [ ${conStatus::9} = connected ]
						then
							conType=${conStatus:9:4}
							if [ $conType = ${PDP_type:2:2} ]
							then
								echo ' '$conStatus' -> disconnected, error code '$err_code
								conStatus=disconnected
								release_interface
								echo 'Reconnect modem'
								COMMAND="AT^NDISDUP=1,1" gcom -d "$device" -s /etc/gcom/at.gcom
							elif [ $conType = V4V6 ] || [ $conType = V6V4 ]
							then
								echo ' '$conStatus' -> disconnected, error code '$err_code
								[ ${PDP_type:2:2} = V6 ] && conStatus=connectedV4 || conStatus=connectedV6
							fi
						elif [ $conStatus = registered ]
						then
							echo 'Invalid APN'
							proto_notify_error "$interface" INV_APN
							proto_block_restart "$interface"
							return 1
						fi
					fi
					;;
	
				+CMTI )
					[ "$atc_debug" -ge 1 ] && echo $URCline
					SMSindex=$(echo $URCvalue | awk -F ',' '{print $2}')
					atOut=$(COMMAND="AT+CMGR=${SMSindex}" gcom -d "$device" -s /etc/gcom/getrun_at.gcom)
					dateTime=20$(echo "$atOut" | grep CMGR: | awk -F '"' '{print $6}' | awk -F '+' '{print $1}' | sed -e 's/\//-/g' | sed -e 's/,/_/g')
					sender=$(echo "$atOut" | grep CMGR: | awk -F '"' '{print $4}')
					echo 'SMS received from '$sender
					SMSlines=$(echo "$atOut" | wc -l)
					SMSlines=$((SMSlines-2))
					x=3
					while [ $x -le $SMSlines ]
					do
							if [ $x -eq 3 ]
							then
									SMStext=$(echo "$atOut" | awk "NR==${x}" | sed -e 's/\r//g')
							elif [ $x -le $SMSlines ]
							then
									SMStext=$SMStext$'\n'$(echo "$atOut" | awk "NR==${x}" | sed -e 's/\r//g')
							fi
							x=$((x+1))
					done
					echo $sender > /var/dateTime
					echo $SMStext >> /var/dateTime
					atOut=$(COMMAND="AT+CMGD=$SMSindex" gcom -d "$device" -s /etc/gcom/run_at.gcom)
					;;
	
				^HCSQ )
					[ "$atc_debug" -eq 2 ] && echo $URCline
					[ ${conStatus::9} = connected ] && {
						rat=$(echo $URCvalue | awk -F ',' '{print $1}')
						rssi=$(echo $URCvalue | awk -F ',' '{print $2}')
						rsrp=$(echo $URCvalue | awk -F ',' '{print $3}')
						sinr=$(echo $URCvalue | awk -F ',' '{print $4}')
						rsrq=$(echo $URCvalue | awk -F ',' '{print $5}')
						[ "$rat" = 'LTE' ] && {
							[ $rssi -lt 255 ] && rssi=$((-121+$rssi))
							[ $rsrp -lt 255 ] && rsrp=$((-141+$rsrp))
							[ $sinr -lt 255 ] && {
								sinr=$(($sinr*2))
								sinr=$((-202+$sinr))
								sinr=${sinr:: -1}'.'${sinr: -1}
							}
							[ $rsrq -lt 255 ] && {
								rsrq=$(($rsrq*5))
								rsrq=$((-200+$rsrq))
								rsrq=${rsrq:: -1}'.'${rsrq: -1}
							}
						}
						json_init
						json_load_file /var/3gpp/cell
						json_add_string rssi "${rssi}"
						json_add_string rsrp "${rsrp}"
						json_add_string sinr "${sinr}"
						json_add_string rsrq "${rsrq}"
						json_close_object
						[ "$atc_debug" -eq 2 ] && echo $(json_dump)
						echo $(json_dump) > /var/3gpp/cell
					}
					;;

				^PLMN )
					[ "$atc_debug" -ge 1 ] && echo $URCline
					plmn=$(echo $URCvalue | awk -F ',' '{print $1}')
					plmn=$plmn'-'$(echo $URCvalue | awk -F ',' '{print $2}')
					;;

				^HFREQINFO )
					[ "$atc_debug" -eq 2 ] && echo $URCline
					RAT=$(echo $URCvalue | awk -F ',' '{print $2}')
					[ "$RAT" = 6 ] && {
						band=$(echo $URCvalue | awk -F ',' '{print $3}')
						arfcn=$(echo $URCvalue | awk -F ',' '{print $4}')
						bw=$(echo $URCvalue | awk -F ',' '{print $6}')
						bw=$(($bw/1000))
					}
					json_init
					json_load_file /var/3gpp/cell
					json_add_string band "${band}"
					json_add_string bandwidth "${bw}"
					json_add_string arfcn "${arfcn}"
					json_add_string scell "${scell}"
					json_add_string tac "${tac}"
					json_add_string pci "-"
					json_close_object
					[ "$atc_debug" -eq 2 ] && echo $(json_dump)
					echo $(json_dump) > /var/3gpp/cell
					;;

				^RSSI|\
				^CERSSI|\
				^ANLEVEL|\
				^LCACELLURC|\
				*'AT^HCSQ?'*|\
				*'AT^HFREQINFO?'* )
					[ "$atc_debug" -eq 2 ] && echo $URCline
					;;

				^FOTASTATE )
					echo $URCline
					;;

				'OK'* )
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
