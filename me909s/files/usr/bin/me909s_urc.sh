#!/bin/sh
# 
# mrhaav 2022-11-02
# Huawei ME909s-120 New SMS message indications
#

URCdev=$(uci get network.wwan.ttyURC)

# Disable unsolicted indications
atOut=$(COMMAND="AT^CURC=0" gcom -d "$URCdev" -s /etc/gcom/run_at.gcom)

# SMS in text format
atOut=$(COMMAND="AT+CMGF=1" gcom -d "$URCdev" -s /etc/gcom/run_at.gcom)

# Enable New Message Indications to TE
atOut=$(COMMAND="AT+cnmi=0,1" gcom -d "$URCdev" -s /etc/gcom/getrun_at.gcom)

while read URCline
do
	if [ ${#URCline} -gt 4 ]
	then
		URCcommand=$(echo $URCline | awk -F ':' '{print $1}')
		URCcommand=${URCcommand:1}
		URCvalue=$(echo $URCline | awk -F ' ' '{print $2}')
		case $URCcommand in
				'CMTI' )
					/usr/bin/me909s_sms_r.sh $URCvalue 2> /dev/null
					;;
				* )
					;;
		esac
	fi
done < ${URCdev}
