#
# Downloaded from realtek official site [https://www.realtek.com/component/zoo/category/network-interface-controllers-10-100-1000m-gigabit-ethernet-pci-express-software]
# Modified for RTL8111E and customized LEDs
#
# Replace orginal Makefile with this file
#


include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=r8168
PKG_VERSION:=8.048.03
PKG_RELEASE:=4


PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define KernelPackage/r8168
  TITLE:=Driver for Realtek r8168 chipsets
  SUBMENU:=Network Devices
  VERSION:=$(LINUX_VERSION)-$(PKG_RELEASE)
  FILES:= $(PKG_BUILD_DIR)/r8168.ko
  AUTOLOAD:=$(call AutoProbe,r8168)
  DEFAULT:=y
endef

define KernelPackage/r8168/description
 Driver, version $(PKG_VERSION), for Realtek r8168 chipset with customized LEDs.
endef

R8168_MAKEOPTS= -C $(PKG_BUILD_DIR) \
		PATH="$(TARGET_PATH)" \
		ARCH="$(LINUX_KARCH)" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		TARGET="$(HAL_TARGET)" \
		TOOLPREFIX="$(KERNEL_CROSS)" \
		TOOLPATH="$(KERNEL_CROSS)" \
		KERNELPATH="$(LINUX_DIR)" \
		KERNELDIR="$(LINUX_DIR)" \
		LDOPTS=" " \
		DOMULTI=1

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)
endef

define Build/Compile
	$(MAKE) $(R8168_MAKEOPTS) modules
endef

$(eval $(call KernelPackage,r8168))