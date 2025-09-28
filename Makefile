# Target platform and packaging scheme
ARCHS = arm64
TARGET = iphone:clang:16.5:13.0
INSTALL_TARGET_PROCESSES = YouTubeMusic
PACKAGE_VERSION = 2.3.1

ifeq ($(ROOTLESS),1)
	THEOS_PACKAGE_SCHEME = rootless
else ifeq ($(ROOTHIDE),1)
	THEOS_PACKAGE_SCHEME = roothide
endif

# Global flags to apply to all source files in the project.
# This suppresses the "variable length array" warning-as-error from newer compilers.
ADDITIONAL_CFLAGS += -Wno-error=vla-cxx-extension
ADDITIONAL_CXXFLAGS += -Wno-error=vla-cxx-extension

include $(THEOS)/makefiles/common.mk

# Tweak-specific settings
TWEAK_NAME = YTMusicUltimate

# Source files
$(TWEAK_NAME)_FILES = $(shell find Source -name '*.xm' -o -name '*.x' -o -name '*.m')
ifeq ($(SIDELOADING),1)
	$(TWEAK_NAME)_FILES += Sideloading.xm
endif

# Tweak compiler flags and linked libraries/frameworks
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -DTWEAK_VERSION=$(PACKAGE_VERSION)
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation AVFoundation AudioToolbox VideoToolbox
$(TWEAK_NAME)_OBJ_FILES = $(shell find Source/Utils/lib -name '*.a')
$(TWEAK_NAME)_LIBRARIES = bz2 c++ iconv z

include $(THEOS_MAKE_PATH)/tweak.mk
