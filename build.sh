#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p build/'JIAYU Token Float 2.0.app'/Contents/{MacOS,Resources}
APP='build/JIAYU Token Float 2.0.app'
xcrun swiftc -O -module-cache-path build/ModuleCache -target arm64-apple-macos13.0 Sources/Core.swift Sources/Interaction.swift Sources/App.swift Sources/Tests.swift -o "$APP/Contents/MacOS/TokenFloat"
cp Assets/logo.png "$APP/Contents/Resources/logo.png"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp README.md "$APP/Contents/Resources/使用说明.md"
cp ThirdParty/NOTICE.md "$APP/Contents/Resources/NOTICE.md"
cp ThirdParty/ccusage-LICENSE "$APP/Contents/Resources/ccusage-LICENSE"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TokenFloat</string>
<key>CFBundleIdentifier</key><string>studio.jiayu.tokenfloat</string>
<key>CFBundleName</key><string>JIAYU Token Float 2.0</string>
<key>CFBundleShortVersionString</key><string>2.0.0</string>
<key>CFBundleVersion</key><string>200</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
"$APP/Contents/MacOS/TokenFloat" --self-test
