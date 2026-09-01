#!/bin/bash
set -e

echo "=========================================="
echo "      Building DemoOverlayUI.dylib        "
echo "=========================================="

ARCHS=${ARCHS:-"-arch arm64 -arch arm64e"}
MIN_IOS=${MIN_IOS:-"12.0"}

echo "[*] Architecture: $ARCHS"
echo "[*] Min iOS Target: $MIN_IOS"

make clean
make ARCHS="$ARCHS" MIN_IOS="$MIN_IOS"

echo ""
echo "=== Output Details ==="
file DemoOverlayUI.dylib
if command -v lipo >/dev/null 2>&1; then
    lipo -info DemoOverlayUI.dylib
fi

echo ""
echo "[✓] Build complete: $(pwd)/DemoOverlayUI.dylib"
