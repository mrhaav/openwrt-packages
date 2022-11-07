#!/bin/sh
#
# mrhaav 2022-11-05
# SMS send script

DEV=$(uci get network.wwan.ttyDEV)

failedFolder=/var/sms/failed
mkdir -p $failedFolder
smsOK=true

Bnumber=$(echo "$1" | sed -n '1p')
SMStext=$(echo "$1" | sed -n '2,$p')
while [ -n "$SMStext" ]
do
	atOut=$(DEST=$Bnumber MSG=${SMStext::160} gcom -d "$DEV" -s /etc/gcom/sendSMS.gcom)
	[ $atOut != 'OK' ] && smsOK=false
	SMStext=${SMStext:160}
done
if $smsOK
then
	logger -t me909s_t SMS sent to $Bnumber
else
	logger -t me909s_t Failed to send sms to "$Bnumber"
	dateTime=$(date +'%Y%m%d_%H%M%S')
	echo "$Bnumber" > ${failedFolder}/sms_${dateTime}
	echo "$SMStext" >> ${failedFolder}/sms_${dateTime}
fi
