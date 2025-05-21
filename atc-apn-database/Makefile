include $(TOPDIR)/rules.mk

PKG_NAME:=atc-apn-database
PKG_VERSION:=20250521
PKG_RELEASE:=1.21

PKG_MAINTAINER:=SuperKali <hello@superkali.me>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=python3/host

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=APN Database for automatic detection
  SUBMENU:=WWAN
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  APN database for automatic detection based on MCC/MNC.
  Derived from Android Open Source Project APN database.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./files/apn_converter.py $(PKG_BUILD_DIR)/
endef

define Build/Configure
	wget -O $(PKG_BUILD_DIR)/apns-full-conf.xml.b64 "https://android.googlesource.com/device/sample/+/refs/heads/main/etc/apns-full-conf.xml?format=TEXT" || \
		(echo "Failed to download APN database"; exit 1)
	cat $(PKG_BUILD_DIR)/apns-full-conf.xml.b64 | base64 -d > $(PKG_BUILD_DIR)/apns-full-conf.xml
endef

define Build/Compile
	cd $(PKG_BUILD_DIR) && \
		python3 ./apn_converter.py ./apns-full-conf.xml ./apn_database.json && \
		echo "APN database size: $$(du -h ./apn_database.json | cut -f1)"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/atc
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/apn_database.json $(1)/etc/atc/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))