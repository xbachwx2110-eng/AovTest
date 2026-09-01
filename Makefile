# Makefile for compiling DemoOverlayUI.dylib using clang (macOS / Xcode CLI)

TARGET   ?= DemoOverlayUI.dylib
CC       ?= xcrun -sdk iphoneos clang

ARCHS   ?= -arch arm64 -arch arm64e
MIN_IOS ?= 12.0
SDK_PATH = $(shell xcrun --sdk iphoneos --show-sdk-path)

CFLAGS   = $(ARCHS) -isysroot $(SDK_PATH) -miphoneos-version-min=$(MIN_IOS) -fobjc-arc -Iinclude -Isrc -O2
LDFLAGS  = -dynamiclib -framework Foundation -framework UIKit -framework CoreGraphics -framework QuartzCore

SRCS = src/DemoOverlayWindow.m \
       src/DemoFloatingButton.m \
       src/DemoMockMapView.m \
       src/DemoMenuViewController.m \
       src/DemoOverlayEntry.m

OBJS = $(SRCS:.m=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
	@if command -v codesign >/dev/null 2>&1; then \
		echo "Ad-hoc code signing $(TARGET)..."; \
		codesign -fs - $@ 2>/dev/null || true; \
	fi
	@echo "Successfully built $(TARGET)"

%.o: %.m
	$(CC) $(CFLAGS) -c $< -o $@

package: $(TARGET)
	zip -r DemoOverlayUI.zip $(TARGET) include/
	@echo "Packaged $(TARGET) into DemoOverlayUI.zip"

clean:
	rm -f src/*.o $(TARGET) DemoOverlayUI.zip

.PHONY: all clean package
