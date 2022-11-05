#!/bin/sh
#
# 2022-11-02

# SMS rules
DEV=$(uci get network.wwan.ttyDEV)
updateFirewall() {
	action=$(echo "$1" | sed -n '1p' | sed -e 's/[\r\n]//g')
	IPaddress=$(echo "$1" | sed -n '2p' | sed -e 's/[\r\n]//g')
	logger -t mem909s_r $action $IPaddress
	if [ "$action" = 'Open' ] && [ -n "$IPaddress" ]
	then
# Ping
		oldIP=$(uci get firewall.ping.src_ip | awk -F ' ' '{print $1}')
		while [ ! -z "$oldIP" ]
		do
			uci del_list firewall.ping.src_ip=$oldIP
			oldIP=$(uci get firewall.ping.src_ip | awk -F ' ' '{print $1}')
		done
		uci add_list firewall.ping.src_ip=$IPaddress
		uci set firewall.ping.enabled=1
# openVPN
		oldIP=$(uci get firewall.openVPN.src_ip | awk -F ' ' '{print $1}')
		while [ ! -z "$oldIP" ]
		do
			uci del_list firewall.openVPN.src_ip=$oldIP
			oldIP=$(uci get firewall.openVPN.src_ip | awk -F ' ' '{print $1}')
		done
		uci add_list firewall.openVPN.src_ip=$IPaddress
		uci set firewall.openVPN.enabled=1
# RDP
		uci set firewall.RPD.src_ip=$IPaddress
		uci set firewall.RDP.enabled=1
		uci commit firewall
	elif [ "$action" = 'Close' ]
	then
		uci set firewall.ping.enabled=0
		uci set firewall.openVPN.enabled=0
		uci set firewall.RDP.enabled=0
		uci commit firewall
	fi

	/etc/init.d/firewall restart 1>/dev/null 2>&1
}


bagaAlarm() {
	action=$(echo "$1" | sed -n '1p' | sed -e 's/[\r\n]//g')
	if [ ${action:0:1} = 'B' ]
	then
		mqttMessage='Cancel'
		alarmCode=${action:1:4}
		postTopic='Alarm'
	elif [ ${action:0:1} = '1' ]
	then
		mqttMessage='Raised'
		alarmCode=${action:0:4}
		postTopic='Alarm'
	else
		postTopic='Status'
		alarmCode=$(echo $action | awk -F '=' '{print $1}')
		mqttMessage=$(echo $action | awk -F '=' '{print $2}')
		mqttMessage='{"parameterName":"'$alarmCode'","Value":'$mqttMessage',"dateTime":"'$dateTime'"}'
	fi
	case $alarmCode in
		1111 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Minor'
			fi
			mqttMessage='{"alarmName":"Flocculants","alarmStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		1114 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Minor'
			fi
			mqttMessage='{"alarmName":"LowLevelSludgeSeparator","alarmStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		1124 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Major'
			fi
			mqttMessage='{"alarmName":"HighLevelSludgeSeparator","alarmStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		1224 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Major'
			fi
			mqttMessage='{"alarmName":"LongPumptime","alarmStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		1264 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Major'
			fi
			mqttMessage='{"alarmName":"MaxPumptime","alarmStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		1300 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Varning'
			fi
			mqttMessage='{"alarmName":"Powerfailure","alarmStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		1359 )
			mqttMessage='{"alarmName":"GSMmodulOK","alarmStatus":"Notice","dateTime":"'$dateTime'"}' ;;
		1389 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Major'
			fi
			mqttMessage='{"alarmName":"FuseF1","alarmStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		1444 )
			mqttMessage='{"alarmName":"Calibration","alarmStatus":"Notice","dateTime":"'$dateTime'"}' ;;
		1459 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Minor'
			fi
			mqttMessage='{"alarmName":"LowTemperature","alarmaStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		1534 )
			if [ $mqttMessage == 'Raised' ]
			then
				mqttMessage='Minor'
			fi
			mqttMessage='{"alarmName":"LevelSensorError","alarmaStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			;;
		* )
			if [ $postTopic == 'Alarm' ]
			then
				mqttMessage='{"alarmName":"'$alarmCode'","alarmStatus":"'$mqttMessage'","dateTime":"'$dateTime'"}'
			fi
			;;
	esac
	
	mosquitto_pub -h 192.168.7.99 -t Arholma/Baga/$postTopic -m $mqttMessage
	
	if [ $postTopic == 'Alarm' ]
	then
		randomSMS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 3)
		echo '+46708331512' > /var/sms/Baga$randomSMS
		echo 'Baga '$(echo $mqttMessage | jq -r .alarmName) >> /var/sms/Baga$randomSMS
		echo $(echo $mqttMessage | jq -r .alarmStatus)' '$(echo $mqttMessage | jq -r .dateTime) >> /var/sms/Baga$randomSMS
		mv /var/sms/Baga$randomSMS /var/spool/send/Baga$randomSMS
	fi

}


# Main
# Allowed receivers

SMSindex=$(echo $1 | awk -F ',' '{print $2}')

atOut=$(COMMAND="AT+CMGR=${SMSindex}" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom)

dateTime=20$(echo "$atOut" | grep CMGR: | awk -F '"' '{print $6}' | awk -F '+' '{print $1}' | sed -e 's/\///g' | sed -e 's/,/T/g' | sed -e 's/://g')
sender=$(echo "$atOut" | grep CMGR: | awk -F '"' '{print $4}')
logger -t me909s_r -p 6 SMS received from $sender
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

atOut=$(COMMAND="AT+CMGD=$SMSindex" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)

case $sender in
	'+46708331512' )
		updateFirewall "$SMStext"
		;;
	'+46701426725' )
		bagaAlarm "$SMStext"
		;;
	* )
		failedSMS="+46708331512"$'\n'"from: ${sender} ${dateTime}"$'\n'${SMStext}		/usr/bin/me909s_sms_t.sh "$failedSMS"		;;
esac
