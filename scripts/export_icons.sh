#!/bin/bash
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  export_icons.sh
#  Rugzak
#
# Export app icons from source SVG to all required PNG sizes for the Xcode asset catalogue
# It eliminates ictool in GitHub Actions / CI. (Xcode in CI might not be able to process .icon files properly)
#

set -euo pipefail

ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
RESOURCES="${SRCROOT}/Resources"

build_icns() {
    local icon="$1"
    local appiconset="$2"

    mkdir -p $appiconset

    # pt  scale  filename
    local -a entries=(
        "16   1  icon_16x16.png"
        "16   2  icon_16x16@2x.png"
        "32   1  icon_32x32.png"
        "32   2  icon_32x32@2x.png"
        "128  1  icon_128x128.png"
        "128  2  icon_128x128@2x.png"
        "256  1  icon_256x256.png"
        "256  2  icon_256x256@2x.png"
        "512  1  icon_512x512.png"
        "512  2  icon_512x512@2x.png"
    )

    for entry in "${entries[@]}"; do
        read -r pt scale filename <<< "$entry"
        "$ICTOOL" "$icon" --export-image \
            --output-file "${appiconset}/${filename}" \
            --platform macOS --rendition Default \
            --width "$pt" --height "$pt" --scale "$scale"
    done

    cat > "${appiconset}/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "icon_16x16.png",     "idiom" : "mac", "scale" : "1x", "size" : "16x16"   },
    { "filename" : "icon_16x16@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "16x16"   },
    { "filename" : "icon_32x32.png",     "idiom" : "mac", "scale" : "1x", "size" : "32x32"   },
    { "filename" : "icon_32x32@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "32x32"   },
    { "filename" : "icon_128x128.png",   "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png","idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",   "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png","idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",   "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png","idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
}

build_icns "${RESOURCES}/RugzakAppIcon.icon"      "${RESOURCES}/Assets.xcassets/Rugzak.appiconset"
build_icns "${RESOURCES}/RugzakAppIconDebug.icon" "${RESOURCES}/Assets.xcassets/RugzakDebug.appiconset"
