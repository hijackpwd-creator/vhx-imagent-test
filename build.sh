#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
target="build/package/var/jb/Library/MobileSubstrate/DynamicLibraries"
mkdir -p "$target" build/package/DEBIAN dist
# A system-process dylib needs the current arm64e ABI, unlike an ordinary CLI.
xcrun --sdk iphoneos clang -arch arm64e -miphoneos-version-min=15.0 \
  -dynamiclib -fobjc-arc -fblocks -O2 -Wall -Wextra -Werror \
  -framework Foundation Test.m -o "$target/VHXImagentTest.dylib"
ldid -Hsha256 -S "$target/VHXImagentTest.dylib"
xcrun lipo "$target/VHXImagentTest.dylib" -verify_arch arm64e
cp Filter.plist "$target/VHXImagentTest.plist"
cp packaging/control build/package/DEBIAN/control
chmod 644 "$target/VHXImagentTest.dylib" "$target/VHXImagentTest.plist" build/package/DEBIAN/control
dpkg-deb --root-owner-group -Zgzip --build build/package dist/vhx-imagent-test_1.0.0_iphoneos-arm64.deb
cp config.plist README_zh.md dist/
