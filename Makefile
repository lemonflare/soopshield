ARCHS = arm64
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SOOP

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SoopShield

SoopShield_FILES = Tweak.x
SoopShield_CFLAGS = -fobjc-arc
SoopShield_LDFLAGS = -Wl,-dead_strip_dylibs
SoopShield_FRAMEWORKS = Foundation WebKit

include $(THEOS_MAKE_PATH)/tweak.mk
