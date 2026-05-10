#!/bin/bash
set -e

PNG_PATH="/Users/AlexFisenkov_1/.gemini/antigravity/brain/b7794457-ca76-4039-859d-9561a44e645f/macdictate_icon_1774954155536.png"
ICONSET_DIR="MyIcon.iconset"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16     "$PNG_PATH" --out "$ICONSET_DIR/icon_16x16.png"
sips -z 32 32     "$PNG_PATH" --out "$ICONSET_DIR/icon_16x16@2x.png"
sips -z 32 32     "$PNG_PATH" --out "$ICONSET_DIR/icon_32x32.png"
sips -z 64 64     "$PNG_PATH" --out "$ICONSET_DIR/icon_32x32@2x.png"
sips -z 128 128   "$PNG_PATH" --out "$ICONSET_DIR/icon_128x128.png"
sips -z 256 256   "$PNG_PATH" --out "$ICONSET_DIR/icon_128x128@2x.png"
sips -z 256 256   "$PNG_PATH" --out "$ICONSET_DIR/icon_256x256.png"
sips -z 512 512   "$PNG_PATH" --out "$ICONSET_DIR/icon_256x256@2x.png"
sips -z 512 512   "$PNG_PATH" --out "$ICONSET_DIR/icon_512x512.png"
sips -z 1024 1024 "$PNG_PATH" --out "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR"
cp MyIcon.icns assets/AppIcon.icns
rm -rf "$ICONSET_DIR" MyIcon.icns

echo "ICON GENERATION SUCCESS"
