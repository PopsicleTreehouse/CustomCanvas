TARGET := iphone:clang:14.4

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CustomCanvasPrefs

CustomCanvasPrefs_FILES = $(wildcard *.m)
CustomCanvasPrefs_FRAMEWORKS = UIKit
CustomCanvasPrefs_PRIVATE_FRAMEWORKS = Preferences
CustomCanvasPrefs_INSTALL_PATH = /Library/PreferenceBundles
CustomCanvasPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
