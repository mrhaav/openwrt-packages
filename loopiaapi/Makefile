include $(TOPDIR)/rules.mk
 
PKG_NAME:=loopiaapi
PKG_VERSION:=2022-11-12
PKG_RELEASE:=0.8

PKG_MAINTAINER:=Henrik Ginstmark <henrik@ginstmark.se>
PKG_LICENSE:=GPL-2.0


include $(INCLUDE_DIR)/package.mk

define Package/loopiaapi
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Utility for updating DNS via Loopia API
  SUBMENU:=IP Addresses and Names
  PKGARCH:=all
  DEPENDS:=+curl +libxml2-utils
endef

define Package/loopiaapi/description
  Utility for Loopia API to update your DNS entries
endef


define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/loopiaapi/postinst
#!/bin/sh
if [ -e /etc/config/ddns ]
then
	uci set ddns.loopiaapi=service
	uci commit ddns
else
	echo "config service 'loopiaapi'" > /etc/config/ddns
fi
exit 0
endef

define Package/loopiaapi/prerm
#!/bin/sh
uci del ddns.loopiaapi
uci commit ddns
exit 0
endef

define Package/loopiaapi/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/loopiaapi $(1)/usr/bin

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_DATA) ./files/etc/hotplug.d/iface/90-loopia $(1)/etc/hotplug.d/iface
endef
 
$(eval $(call BuildPackage,loopiaapi))
