# COPY THIS EXACT CONTENT TO YOUR INFO.PLIST

## Open Info.plist in Xcode, switch to Source Code view, and replace EVERYTHING with this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<true/>
	</dict>
	<key>UILaunchScreen</key>
	<dict/>
</dict>
</plist>
```

## How to Use This:

1. In Xcode, find or create **Info.plist**
2. Right-click on Info.plist → **Open As → Source Code**
3. **Select ALL** the text (⌘A)
4. **Delete** it
5. **Paste** the XML above
6. **Save** (⌘S)
7. **Clean** (⌘⇧K) and **Build** (⌘B)

## This minimal Info.plist contains ONLY:
- ✅ CFBundleIconName = AppIcon (fixes your error!)
- ✅ Scene manifest for SwiftUI
- ✅ Launch screen config

Xcode will automatically add other required keys during build.
