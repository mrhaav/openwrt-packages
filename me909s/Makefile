include $(TOPDIR)/rules.mk
 
PKG_NAME:=me909s
PKG_VERSION:=2022-01-10
PKG_RELEASE:=0.2

PKG_MAINTAINER:=Henrik Ginstmark <henrik@ginstmark.se>
PKG_LICENSE:=GPL-2.0


include $(INCLUDE_DIR)/package.mk

define Package/me909s
  SECTION:=net
  CATEGORY:=Network
  TITLE:=AT command script for Huawei ME909s-120 LTE modem
  SUBMENU:=WWAN
  PKGARCH:=all
  DEPENDS:=+kmod-usb-net-cdc-ether +kmod-usb-serial-option +comgt
endef

define Package/me909s/description
  AT command script for Huawei ME909s-120 LTE modem
endef


define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/me909s/postinst
#!/bin/sh
uci set network.wwan=interface
uci set network.wwan.device=wwan0
uci set network.wwan.proto=dhcp
uci commit network
exit 0
endef

define Package/me909s/prerm
#!/bin/sh
uci del network.wwan
uci commit network
exit 0
endef

define Package/me909s/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/me909s.sh $(1)/usr/bin

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/ME909s $(1)/etc/init.d

	$(INSTALL_DIR) $(1)/etc/gcom
	$(INSTALL_DATA) ./files/etc/gcom/* $(1)/etc/gcom
endef
 
$(eval $(call BuildPackage,me909s))
