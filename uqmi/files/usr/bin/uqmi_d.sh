#!/bin/sh
#
# uqmi daemon, runs every 30sec
# 1. Check IP-address in get-current-settings
# 2. Send SMS from /var/sms/send
# 3. Check received SMS
# 4. rssi LED trigger
#
# by mrhaav 2022-09-12

. /lib/functions.sh
. /lib/netifd/netifd-proto.sh

# SMS folders
receiveFolder=/var/sms/received
sendFolder=/var/sms/send
mkdir -p $receiveFolder
mkdir -p $sendFolder

interface=$(uci show network | grep qmi | awk -F . '{print $2}')
device=$(uci get network.${interface}.device)
default_profile=$(uci get network.${interface}.default_profile)
ipv6profile=$(uci get network.${interface}.ipv6profile)
smsc=$(uci get network.${interface}.smsc)

json_load "$(ubus call network.interface.${interface} status)"
json_get_var ifname l3_device
json_select data
json_get_vars cid_4 pdh_4 cid_6 pdh_6 zone

if [ ! -n "$pdh_4" ] && [ ! -n "$pdh_6" ]
then
	/etc/init.d/uqmi_d stop 2> /dev/null
fi

logger -t uqmi_d Daemon started

while true
do
# Check wwan connectivity
	if [ -n "$pdh_4" ]
	then
		ipv4connected="$(uqmi -s -d $device --set-client-id wds,$cid_4 --get-current-settings)"
	fi
	if [ -n "$pdh_6" ]
	then
		ipv6connected="$(uqmi -s -d $device --set-client-id wds,$cid_6 --get-current-settings)"
	fi

	if [ "$ipv4connected" = '"Out of call"' ] || [ "$ipv6connected" = '"Out of call"' ]
	then
		logger -t uqmi_d Modem disconnected
		proto_init_update "$ifname" 0
		proto_send_update "$interface"

# IPv4
		if [ -n "$pdh_4" ]
		then
			uqmi -s -d $device --set-client-id wds,"$cid_4" \
				--release-client-id wds

			cid_4=$(uqmi -s -d $device --get-client-id wds)
			uqmi -s -d "$device" --set-client-id wds,"$cid_4" --set-ip-family ipv4
			pdh_4=$(uqmi -s -d $device --set-client-id wds,"$cid_4" \
				--start-network \
				--profile $default_profile)
			if [ "$pdh_4" = '"Call failed"' ]
			then
				logger -t uqmi_d 'Unable to re-connect IPv4 - Interface restarted'
				ifup $interface
				/etc/init.d/uqmi_d stop
			else
				logger -t uqmi_d IPv4 re-connected
			fi
			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_data
			json_add_string "cid_4" "$cid_4"
			json_add_string "pdh_4" "$pdh_4"
			json_add_string zone "$zone"
			proto_close_data
			proto_send_update "$interface"
	
			json_load "$(uqmi -s -d $device --set-client-id wds,$cid_4 --get-current-settings)"
			json_select ipv4
			json_get_var ip_4 ip
			json_get_var gateway_4 gateway
			json_get_var dns1_4 dns1
			json_get_var dns2_4 dns2
			json_get_var subnet_4 subnet
	
			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_ipv4_address "$ip_4" "$subnet_4"
			proto_add_ipv4_route "$gateway_4" "128"
			[ "$defaultroute" = 0 ] || proto_add_ipv4_route "0.0.0.0" 0 "$gateway_4"
			[ "$peerdns" = 0 ] || {
				proto_add_dns_server "$dns1_4"
				proto_add_dns_server "$dns2_4"
			}
			proto_send_update "$interface"
		fi

# IPv6
		if [ -n "$pdh_6" ]
		then
			uqmi -s -d $device --set-client-id wds,"$cid_6" \
				--release-client-id wds

			cid_6=$(uqmi -s -d $device --get-client-id wds)
			uqmi -s -d "$device" --set-client-id wds,"$cid_6" --set-ip-family ipv6
			if [ -n "$pdh_4" ] && [ -n "$pdh_6" ]
			then
				pdh_6=$(uqmi -s -d $device --set-client-id wds,"$cid_6" \
					--start-network)
			elif [ -n "$ipv6profile" ]
			then
				pdh_6=$(uqmi -s -d $device --set-client-id wds,"$cid_6" \
					--start-network \
					--profile $ipv6profile)
			else
				pdh_6=$(uqmi -s -d $device --set-client-id wds,"$cid_6" \
					--start-network \
					--profile $default_profile)
			fi
			if [ "$pdh_6" = '"Call failed"' ]
			then
				logger -t uqmi_d 'Unable to re-connect IPv6 - Interface restarted'
				ifup $interface
				/etc/init.d/uqmi_d stop
			else
				logger -t uqmi_d IPv6 re-connected
			fi
			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_data
			json_add_string "cid_6" "$cid_6"
			json_add_string "pdh_6" "$pdh_6"
			json_add_string zone "$zone"
			proto_close_data
			proto_send_update "$interface"

			json_load "$(uqmi -s -d $device --set-client-id wds,$cid_6 --get-current-settings)"
			json_select ipv6
			json_get_var ip_6 ip
			json_get_var gateway_6 gateway
			json_get_var dns1_6 dns1
			json_get_var dns2_6 dns2
			json_get_var ip_prefix_length ip-prefix-length

			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_ipv6_address "$ip_6" "128"
			proto_add_ipv6_prefix "${ip_6}/${ip_prefix_length}"
			proto_add_ipv6_route "$gateway_6" "128"
			[ "$defaultroute" = 0 ] || proto_add_ipv6_route "::0" 0 "$gateway_6" "" "" "${ip_6}/${ip_prefix_length}"
			[ "$peerdns" = 0 ] || {
				proto_add_dns_server "$dns1_6"
				proto_add_dns_server "$dns2_6"
			}
			proto_send_update "$interface"
		fi
		
		json_load "$(ubus call network.interface.${interface} status)"
		json_select data
		json_get_vars cid_4 pdh_4 cid_6 pdh_6
	fi

# Send SMS
	smsTOsend=$(ls $sendFolder -w 1 | sed -n '1p')
	while [ -n "$smsTOsend" ]
	do
		Bnumber=$(sed -n '1p' $sendFolder/$smsTOsend)
		SMStext=$(sed -n '2,$p' $sendFolder/$smsTOsend)
		logger -t uqmi_d SMS sent to $Bnumber
		if [ -z "$smsc" ]
		then
			uqmi -d $device --send-message "$SMStext" \
							--send-message-target $Bnumber
		else
			uqmi -d $device --send-message "$SMStext" \
							--send-message-target $Bnumber \
							--send-message-smsc $smsc
		fi
		rm $sendFolder/$smsTOsend
		smsTOsend=$(ls $sendFolder -w 1 | sed -n '1p')
		[ -n "$smsTOsend" ] && sleep 1
	done

# Check received SMS
	for storage in sim me
	do
		messageID=$(uqmi -d $device --list-messages --storage $storage  | jsonfilter -e '@[0]')
		while [ -n "$messageID" ]
		do
			json_load "$(uqmi -s -d $device --get-message $messageID --storage $storage 2>/dev/null)"
			json_get_var smsc smsc
			json_get_var sender sender
			json_get_var timestamp timestamp
			json_get_var concat_ref concat_ref
			json_get_var concat_part concat_part
			json_get_var concat_parts concat_parts
			json_get_var text text
			timestamp=$(echo $timestamp | sed -e 's/-//g' | sed -e 's/://g' | sed -e 's/ /T/g')
			if [ -n "$concat_ref" ]
			then
				sms_file=sms_${timestamp}_${concat_ref}_${concat_part}_${concat_parts}
			else
				sms_file=sms_${timestamp}
			fi
			echo "$sender" > $receiveFolder/$sms_file
			echo "$text" >> $receiveFolder/$sms_file
			logger -t uqmi_d SMS received from $sender
			/usr/bin/uqmi_sms.sh $receiveFolder/${sms_file} 2> /dev/null
			uqmi -d $device --delete-message $messageID --storage $storage
			sleep 1
			messageID=$(uqmi -d $device --list-messages --storage $storage  | jsonfilter -e '@[0]')
		done
	done

# LED trigger
	rssi=$(uqmi -s -d $device --get-signal-info | jsonfilter -e '@["rssi"]')
	/usr/bin/uqmi_led.sh "$rssi" 2> /dev/null


	sleep 30
done
