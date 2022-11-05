# openwrt-packages

Add feed to feeds.conf.default: `src-git mrhaav https://github.com/mrhaav/openwrt-packages.git`\
\
\
**leds-apu1**

Kernel module to access the three front LEDs and the push button on the PC Engines APU1.\
LEDs are called apu:1, apu:2 and apu:3. The push buttom is accessible via GPIO and `cat /sys/class/gpio/gpio187/value`. 1 = unpressed, 0 = pressed.\
You can use packages like `kmod-ledtrig-netdev` to trigger the LEDs for network activity.\
\
\
**LoopiaAPI**

Hotplug script for updating Loopia DNS via LoopiaAPI, https://www.loopia.com/api/. \
LoopiaAPI is triggered from `etc/udhcpc.user` and `etc/hotplug.d/iface/90-loopia`. `udhcpc.user` is triggered when the DHCP client is updating the IP-address and `90-loopia` is triggered when an interface is updated with ip address and route. `90-loopia` could be usefull for LTE modem if they doesn´t support DCHP.\
Messages are written to System Log.\
\
You need to configure your Loopia API username and password and "connect" the interface to your domain name.
```
uci set ddns.loopiaapi.username='user@loopiaapi'
uci set ddns.loopiaapi.password='password'
uci set ddns.loopiaapi.wan='your.domain.com'
uci commit ddns
```
\
As long as the DNS has correct information nothing is sent to Loopia. You can force regulary updates, in days, with:
```
uci set ddns.loopiaapi.forced_update='30'
uci commit ddns
```
Packages dependencies:\
`curl`
`libxml2-utils`

libxml2-utils is missing in 19.07. You can download from 21.02 and install manually or compile from here. "Override" 19.07 version with:\
`scripts/feeds uninstall libxml2`\
`scripts/feeds install -p mrhaav libxml2`\
\
\
**luci - luci-proto-mbim**

Just a copy of luci-proto-qmi, but support for mbim protocol.\
\
\
**me909s**

AT command script for Huawei ME909s-120 LTE modem.

You need to configure you wwan interface:\
Network - Interfaces - wwan\
&nbsp;&nbsp;&nbsp;Protocol: DHCP client\
Edit - Firewall Settings\
&nbsp;&nbsp;&nbsp;Create / Assign firewall-zone: Add wwan to correct firewall-zone
	
Add APN setting and USB device number:
```
uci set network.wwan.apn=internet
uci set network.wwan.pdp_type=IP
uci set network.wwan.ttyUSB=/dev/ttyUSB0
uci set network.wwan.ttyURC=/dev/ttyUSB2
uci commit network
```
Reboot router\
\
PKG_RELEASE:=0.3\
PKG_VERSION:=2022-11-05
- hotplug script for re-connect network initiated disconnects
- Event based SMS receiver. Make your own roles in `/usr/bin/me909s_sms_r.sh`
- SMS sender. `/usr/bin/me909s_sms_t.sh Bnumber'\n'SMStext`


Packages dependencies:\
`kmod-usb-net-cdc-ether`
`kmod-usb-serial-option`
`comgt`\
\
\
**r8168**

NIC drivers to Realtek RTL8111E with support for customized LEDs. Designed for PC Engines APU1.\
The APU1 board has LED0 (green) and LED1 (amber) connected. Default flashes LED0 for network activity, for all speeds, and LED1 is lit for Link100M.
I have change the drivers so LED0 is lit for Link, all speeds, and flashes for network activity, all speeds, and LED1 is lit for Link1G.\
That equals hex-word 0x004F, according to table:
|      | Activity | Link1G | Link100M | Link10M |
| --- | :---: | :---: | :---: | :---: | 
| LED0 | Bit3 | Bit2 | Bit1 | Bit0 |
| LED1 | Bit7 | Bit6 | Bit5 | Bit4 |
| N/A | Bit11 | Bit10 | Bit9 | Bit8 |
| LED3 | Bit15 | Bit14 | Bit13 | Bit12 |

If you want a different behavior, just change the hex-word in file r8168_n.c under section "Enable Custom LEDs".

Files "Realtek_" are the original files from the driver package, https://www.realtek.com/en/component/zoo/category/network-interface-controllers-10-100-1000m-gigabit-ethernet-pci-express-software
\
\
\
**umbim**

Control utility for mobile broadband modems. Based on https://git.openwrt.org/project/umbim.git 2021-08-18.

\
\
**uqmi**

Control utility for mobile broadband modems. Based on https://git.openwrt.org/project/uqmi.git 2021-11-22.\
This version use APN profiles. The default APN profile is verified before the modem goes online. If the default profile is not correct, the modem is set to Airplane mode on and the profile is corrected. Then the modem is set to Airplane mode off.\
If PDP-type = IPv4v6, dual-stack will be activate.

PKG_RELEASE:=0.9\
PKG_VERSION:=2022-09-13
- wds: Added --delete-profile
- qmi.sh: raw-ip is the default data format
- qmi.sh: If you need a different IPv6 APN to activate dual-stack, define the APN in Luci as IPv4 and configure manually the IPv6 profile with uqmi --create-profile/--modify-profile. Add the IPv6 profile number with:
```
uci set network.<your interface>.ipv6profile=<ipv6 profile number>
uci commit network
```
- qmi.sh: If you have you modem in poor radio coverage, you can let the modem search for network for ever (default, it will search for 35 sec). Just add:
```
uci set network.<your interface>.abort_search=false
uci commit network
```
- uqmi_d.sh: You can turn off the daemon with:
```
uci set network.<your interface>.daemon=false
uci commit network
```

PKG_RELEASE:=0.8\
PKG_VERSION:=2022-07-14
- uqmi_d.sh: Added an SMS sender function to the daemon. Store the SMS file in /var/sms/send with the Bnumber, in international format (+46708123456), in the first row and the SMS text in the following rows.
Received SMSs are now stored in /var/sms/received.\
If you have problems with sending SMSs, add the SMSC number with:
```
uci set network.<your interface>.smsc=<SMSC number> (smsc number in international format)
uci commit network
```

PKG_RELEASE:=0.6\
PKG_VERSION:=2022-05-16
- nas: Correction for decoding of plmn_description, in --get-serving-system. Some modems reads the PLMN name, from the SIM card field 6FC5, as 8bit characters. But the information is coded as 7bit GSM characters and stored in 8bit format.

PKG_RELEASE:=0.5\
PKG_VERSION:=2022-04-22
- uqmi_d.sh: An SMS receiver is included in the daemon. The SMS is stored in /var/sms and the file name is sent to script /usr/bin/uqmi_sms.sh. (uqmi_sms.sh is not included in the ipk file)

PKG_RELEASE:=0.4\
PKG_VERSION:=2022-04-22
- uqmi_d.sh: A connectivity daemon is added. It will check modem connectivity every 30sec. If the modem is disconnected, the daemon will re-connected the session and update the interface with the new IP address.\
The daemon will send the RSSI value to script /usr/bin/uqmi_led.sh to trigger signal strenght LEDs. (uqmi_led.sh is not included in the ipk file)

PKG_RELEASE:=0.4\
PKG_VERSION:=2022-03-15
- wms: Added --storage argument for reading SMS from me, not only from sim. *Included in uqmi.git 2022-05-04*

PKG_RELEASE:=0.4\
PKG_VERSION:=2022-03-12
- wms: Corrected too short received SMS. When characters with ascii values bigger than 0x7f are used, the length of the received text message is too short. *Included in uqmi.git 2022-03-12*

PKG_RELEASE:=0.4\
PKG_VERSION:=2021-12-22
- qmi.sh: Some minor cosmetic corrections.

PKG_RELEASE:=0.3\
PKG_VERSION:=2021-12-22
- qmi.sh: Added support for PLMN configuration and PIN code.

PKG_RELEASE:=0.2\
PKG_VERSION:=2021-12-22
- qmi.sh: Support for dual-stack. PDP Type = IPv4v6 will use IPv4 for default connection and IPv6 for secondary connection. PLMN configuration not supported.

- nas: Added support for three digit MNC even if the value is less then 100. MNC = 008 will be a three-digit and 08 will be a two-digit MNC.
- wds: Added command: --create-profile
- nas: Added decoding of lte_system_info_v2.cid and intrafrequency_lte_info_v2.global_cell_id to enodeb_id and cell_id and decoding of wcdma_system_info_v2.cid to rnc_id and cell_id. Change order to mcc-mnc-tac/lac-enodeb_id/rnc_id-cell_id. *Included in uqmi.git 2022-05-04*
- wds: Added command: --get-default-profile-number, --get-profile-settings, --modify-profile
- dms: Added command: --get-device-operating-mode *Included in uqmi.git 2022-02-22*


Compiling:\
If you don´t find uqmi with desciption: `Control utility for mobile broadband modems, mod by mrhaav` in `make menuconfig` you need to "override" official uqmi.\
`scripts/feeds uninstall uqmi`\
`scripts/feeds install -p mrhaav uqmi`

\
\
**usbmode**

USB mode switch utility based on https://git.openwrt.org/project/usbmode.git 2017-12-19.\
Added config #0 and a 100milliseconds delay before switching to actual config. *Included in usbmode.git 2022-02-24*\
Now Huawei ME909s-120 can switch to MBIM protocol, just add:
```
                "12d1:15c1": {
                        "*": {
                                "msg": [  ],
                                "mode": "Huawei",
                                "config": 3
                        }
                },
```
to /etc/usb.mode.json
