TARGET := iphone:clang:14.4
INSTALL_TARGET_PROCESSES = SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomCanvas

CustomCanvas_FILES = Tweak.xm
CustomCanvas_FRAMEWORKS = CoreFoundation
CustomCanvas_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += customcanvasprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
