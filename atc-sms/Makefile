include $(TOPDIR)/rules.mk
 
PKG_NAME:=atc-sms
PKG_VERSION:=2025.01.30
PKG_RELEASE:=1

PKG_MAINTAINER:=Henrik Ginstmark <henrik@ginstmark.se>
PKG_LICENSE:=GPL-2.0


include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Command line SMS support to protocol atc
  SUBMENU:=WWAN
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  SMS support to protocol atc
endef


define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/* $(1)/usr/bin

	$(INSTALL_DIR) $(1)/etc/gcom
	$(INSTALL_DATA) ./files/etc/gcom/* $(1)/etc/gcom
endef
 
$(eval $(call BuildPackage,$(PKG_NAME)))
