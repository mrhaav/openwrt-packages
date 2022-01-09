#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=leds-apu1
PKG_RELEASE:=1

PKG_MAINTAINER:=Henrik Ginstmark <henrik@ginstmark.se>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/leds-apu1
  SUBMENU:=LED modules
  TITLE:= PC Engines APU1 LED support
  DEPENDS:= @GPIO_SUPPORT @TARGET_x86
  FILES:=$(PKG_BUILD_DIR)/leds-apu1.ko
  AUTOLOAD:=$(call AutoLoad,41,leds-apu1,1)
  KCONFIG:=
endef

define KernelPackage/leds-apu1/description
  Driver for the PC Engines APU1 LEDs and buttom.
endef

EXTRA_KCONFIG:= \
	CONFIG_LEDS_APU1=m

EXTRA_CFLAGS:= \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=m,%,$(filter %=m,$(EXTRA_KCONFIG)))) \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=y,%,$(filter %=y,$(EXTRA_KCONFIG)))) \

MAKE_OPTS:= \
	$(KERNEL_MAKE_FLAGS) \
	M="$(PKG_BUILD_DIR)" \
	EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
	$(EXTRA_KCONFIG)

define Build/Compile
	 $(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		modules
endef

$(eval $(call KernelPackage,leds-apu1))
