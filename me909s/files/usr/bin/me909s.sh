#!/bin/sh
# 
# mrhaav 2022-11-05
# Huawei ME909s-120 modem
#
# ^SYSCFGEX: "00",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF

DEV=$(uci get network.wwan.ttyDEV)
if [ -z "$DEV" ]
then
	modemUSBport=$(dmesg | grep 'GSM modem' | grep 'usb ' | awk 'NR==1' | awk -F 'ttyUSB' '{print $NF}')
	DEV='/dev/ttyUSB'$modemUSBport
	uci set network.wwan.ttyDEV=$DEV
	uci set network.wwan.ttyURC='/dev/ttyUSB'$(($modemUSBport+2))
	uci commit network
	/ect/init.d/me909s_sms restart
fi

modemInit=$(cat /var/modem.status 2>null)
echo nOK > /var/modem.status


creg () {
	case $1 in
		0 )
			registration=" not registered" ;;
		1 )
			registration=" registered" ;;
		2 )
			registration=" searching" ;;
		3 )
			registration=" registration denied" ;;
		4 )
			registration=" unknown" ;;
		5 )
			registration=" registered - roaming" ;;
		* )
			registration=$1
	esac
	echo "$registration"
}


cops () {
	atOut=$(COMMAND="AT+cops?" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | grep COPS:)
	operator=$(echo $atOut  | awk -F , '{print $3}'  | sed -e 's/"//g')
	atOut=$(echo $atOut  | awk -F , '{print $4}' | sed -e 's/[\r\n]//g')

	case $atOut in
		0|1|3 )
			rat=GSM ;;
		2|4|5|6 )
			rat=UTRAN ;;
		7 )
			rat=LTE ;;
		* )
			rat=$atOut ;;
	esac
	echo Connected to $operator on $rat
}


# Modem initialization
if [ "$modemInit" != "OK" ]
then
	logger -t me909s -p 6 Modem initialization
	APN=$(uci get network.wwan.apn)
	pdpType=$(uci get network.wwan.pdp_type)
	
# Set error codes to verbose
	atOut=$(COMMAND="AT+CMEE=2" gcom -d "$DEV" -s /etc/gcom/run_at.gcom | sed -e 's/[\r\n]//g')
	while [ "$atOut" != 'OK' ]
	do
		logger -t me909s -p 6 Modem not ready yet
		atOut=$(COMMAND="AT+CMEE=2" gcom -d "$DEV" -s /etc/gcom/run_at.gcom | sed -e 's/[\r\n]//g')
	done
	
# Check SIMcard and PIN status
	atOut=$(COMMAND="AT+CPIN?" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | grep CPIN: | awk -F ' ' '{print $2 $3}' | sed -e 's/[\r\n]//g')
	case $atOut in
		READY )
			logger -t me909s -p 6 SIMcard ready
			;;
		SIMPIN )
			PINcode=$(uci get network.wwan.pincode)
			if [ -z $PINcode ]
			then
				logger -t me909s -p 3 PINcode required but missing
				exit 1
			fi
			atOut=$(COMMAND="AT+CPIN=${PINcode}" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | grep 'CME ERROR:')
			if [ -n "$atOut" ]
			then
				logger -t me909s -p 3 PINcode error: ${atOut:11}
				exit 1
			fi
			logger -t me909s -p 6 PINcode verified
			;;
		* )
			logger -t me909s -p 3 SIMcard error: $atOut
			exit 1
			;;
	esac

# Flight mode on
	logger -t me909s -p 6 Flightmode on
	atOut=$(COMMAND="AT+CFUN=0" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)

# Disable unsolicted indications
#	atOut=$(COMMAND="AT^CURC=0" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)

# Configure APN
	logger -t me909s -p 6 Configure APN
	atOut=$(COMMAND="AT+CGDCONT=0,\"$pdpType\",\"$APN\"" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
	atOut=$(COMMAND="AT+CGDCONT=1,\"$pdpType\",\"$APN\"" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)

# Flight mode off
	logger -t me909s -p 6 Flightmode off
	atOut=$(COMMAND="AT+CFUN=1" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
	sleep 1
	atOut=$(COMMAND="AT+creg?" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | grep CREG: | awk -F , '{print $2}' | sed -e 's/[\r\n]//g')
	while [ $atOut -eq 0 ] || [ $atOut -eq 2 ]
	do
		logger -t me909s -p 6 "$(creg $atOut)"
		sleep 2
		atOut=$(COMMAND="AT+creg?" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | grep CREG: | awk -F , '{print $2}' | sed -e 's/[\r\n]//g')
	done
	logger -t me909s -p 6 "$(creg $atOut)"
	if [ $atOut -eq 3 ] || [ $atOut -eq 4 ]
	then
		logger -t me909s -p 3 Check subscription
		echo nOK > /var/modem.status
		exti 1
	fi

# Check operator
	logger -t me909s -p 6 "$(cops)"

# Activate NDIS application
	atOut=$(COMMAND="AT^NDISDUP=1,1" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | grep IPV4)
	if [ -z "$atOut" ]
	then
		logger -t me909s -p 3 Could not activate APN, check APN settings
		exit 1
	fi
	echo OK > /var/modem.status

# Restart modem
else
	logger -t me909s -p 4 Restart modem

# Flight mode on
	logger -t me909s -p 6 Flightmode on
	atOut=$(COMMAND="AT+CFUN=0" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
	sleep 1

# Flight mode off
	logger -t me909s -p 6 Flightmode off
	atOut=$(COMMAND="AT+CFUN=1" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
	sleep 1
	atOut=$(COMMAND="AT+creg?" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | grep CREG: | awk -F , '{print $2}' | sed -e 's/[\r\n]//g')
	while [ $atOut -eq 0 ] || [ $atOut -eq 2 ]
	do
		logger -t me909s -p 6 "$(creg $atOut)"
		sleep 2
		atOut=$(COMMAND="AT+creg?" gcom -d "$DEV" -s /etc/gcom/getrun_at.gcom | grep CREG: | awk -F , '{print $2}' | sed -e 's/[\r\n]//g')
	done
	logger -t me909s -p 6 "$(creg $atOut)"

# Activate NDIS application
	atOut=$(COMMAND="AT^NDISDUP=1,1" gcom -d "$DEV" -s /etc/gcom/run_at.gcom)
	logger -t me909s -p 6 Modem connected
	echo OK > /var/modem.status
fi
