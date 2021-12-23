# openwrt-packages

Add feed to feeds.conf.default:
`src-git mrhaav https://github.com/mrhaav/openwrt-packages.git`

\
**apu1-leds_buttom**

Kernel module to access the three front LEDs and the push button on the PC Engines APU1.\
LEDs are called apu:1, apu:2 and apu:3. The push buttom is accessible via GPIO and `cat /sys/class/gpio/gpio187/value`. 1 = unpressed, 0 = pressed.\
You can use packages like `kmod-ledtrig-netdev` to trigger the LEDs for network activity.\
\
\
**r8168-8.048.03**

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
**uqmi**

Control utility for mobile broadband modems. Based on https://git.openwrt.org/project/uqmi.git 2021-11-22.

PKG_RELEASE:=0.2\
PKG_VERSION:=2021-12-15
- qmi.sh: Support for dual-stack. PDP Type = IPv4/IPv6 will use IPv4 for default connection and IPv6 for secocondary connection. PLMN configuration not supported and PIN code must be de-activated.

- wds: Added command: --create-profile
- nas: Add decoding of lte_system_info_v2.cid and intrafrequency_lte_info_v2.global_cell_id to enodeb_id and cell_id and decoding of wcdma_system_info_v2.cid to rnc_id and cell_id. Change order to mcc-mnc-tac/lac-enodeb_id/rnc_id-cell_id.
- wds: Added command: --get-default-profile-number, --get-profile-settings, --modify-profile
- dms: Added command: --get-device-operating-mode


Compiling:
If you don´t find uqmi with desciption: `Control utility for mobile broadband modems, mod by mrhaav` in `make menuconfig` you need to "override" official uqmi.\
`scripts/feeds uninstall uqmi`\
`scripts/feeds install -p mrhaav uqmi`
