#!/bin/sh
#
# 2022-11-02

# SMS rules
DEV=$(uci get network.wwan.ttyDEV)

# examlpe of a firewall rule change
rule1() {
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
		uci set firewall.RDP.src_ip=$IPaddress
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



rule2() {
	action=$(echo "$1" | sed -n '1p' | sed -e 's/[\r\n]//g')
# add your own rules

}


# Main
# Read SMS
SMSindex=$(echo $1 | awk -F ',' '{print $2}')
atOut=$(COMMAND="AT+CMGR=${SMSindex}" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom)

dateTime=20$(echo "$atOut" | grep CMGR: | awk -F '"' '{print $6}' | awk -F '+' '{print $1}' | sed -e 's/\//-/g' | sed -e 's/,/_/g')
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

# Allowed receivers
case $sender in
	'+46708123456' )
		rule1 "$SMStext"
		;;
	'+46701987654' )
		rule2 "$SMStext"
		;;
	* )
		failedSMS="+46708123456"$'\n'"from: ${sender} ${dateTime}"$'\n'${SMStext}
		/usr/bin/me909s_sms_t.sh "$failedSMS"
		;;
esac
