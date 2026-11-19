# Makefile for compiling DemoOverlayUI.dylib and LobbyLogger.dylib using clang (macOS / Xcode CLI)

TARGETS  ?= DemoOverlayUI.dylib LobbyLogger.dylib
CC       ?= xcrun -sdk iphoneos clang

ARCHS   ?= -arch arm64 -arch arm64e
MIN_IOS ?= 12.0
SDK_PATH = $(shell xcrun --sdk iphoneos --show-sdk-path)

CFLAGS   = $(ARCHS) -isysroot $(SDK_PATH) -miphoneos-version-min=$(MIN_IOS) -fobjc-arc -Iinclude -Isrc -O2
LDFLAGS  = -dynamiclib -framework Foundation -framework UIKit -framework CoreGraphics -framework QuartzCore

DEMO_SRCS = src/DemoOverlayWindow.m \
            src/DemoFloatingButton.m \
            src/DemoMockMapView.m \
            src/DemoMenuViewController.m \
            src/DemoOverlayEntry.m \
            src/LobbyLogger.m

DEMO_OBJS = $(DEMO_SRCS:.m=.o)

LOGGER_SRCS = src/LobbyLogger.m
LOGGER_OBJS = $(LOGGER_SRCS:.m=.o)

all: $(TARGETS)

DemoOverlayUI.dylib: $(DEMO_OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
	@if command -v codesign >/dev/null 2>&1; then \
		echo "Ad-hoc code signing $@..."; \
		codesign -fs - $@ 2>/dev/null || true; \
	fi
	@echo "Successfully built $@"

LobbyLogger.dylib: $(LOGGER_OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
	@if command -v codesign >/dev/null 2>&1; then \
		echo "Ad-hoc code signing $@..."; \
		codesign -fs - $@ 2>/dev/null || true; \
	fi
	@echo "Successfully built $@"

%.o: %.m
	$(CC) $(CFLAGS) -c $< -o $@

package: all
	zip -r Dylibs_Release.zip DemoOverlayUI.dylib LobbyLogger.dylib include/
	@echo "Packaged into Dylibs_Release.zip"

clean:
	rm -f src/*.o DemoOverlayUI.dylib LobbyLogger.dylib DemoOverlayUI.zip Dylibs_Release.zip

.PHONY: all clean package
