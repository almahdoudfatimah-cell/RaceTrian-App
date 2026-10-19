#!/bin/bash

echo "🎨 AccentColor Fix Script"
echo "=================================================="
echo ""

# Check if Media.xcassets exists
if [ ! -d "Media.xcassets" ]; then
    echo "❌ Error: Media.xcassets not found"
    echo "   Please run this from your project root"
    exit 1
fi

echo "✅ Found: Media.xcassets"
echo ""

# Create AccentColor.colorset directory
mkdir -p Media.xcassets/AccentColor.colorset

echo "✅ Created: Media.xcassets/AccentColor.colorset"

# Create Contents.json for AccentColor
cat > Media.xcassets/AccentColor.colorset/Contents.json << 'EOF'
{
  "colors" : [
    {
      "idiom" : "universal",
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "1.000",
          "green" : "0.820",
          "blue" : "0.000",
          "alpha" : "1.000"
        }
      }
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ Created: AccentColor.colorset/Contents.json"
echo ""
echo "   Color set to: Orange/Yellow (#FFD100)"
echo ""

# Create or verify Media.xcassets Contents.json
if [ ! -f "Media.xcassets/Contents.json" ]; then
    cat > Media.xcassets/Contents.json << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
    echo "✅ Created: Media.xcassets/Contents.json"
else
    echo "✅ Found: Media.xcassets/Contents.json"
fi

echo ""
echo "=================================================="
echo "✅ AccentColor fix complete!"
echo "=================================================="
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Open Xcode"
echo "2. Product → Clean Build Folder (⌘⇧K)"
echo "3. Product → Build (⌘B)"
echo ""
echo "✅ The AccentColor error should be gone!"
echo ""
echo "💡 You can change the color in Xcode:"
echo "   • Click Media.xcassets in Project Navigator"
echo "   • Click AccentColor"
echo "   • Change color in the right panel"
echo ""
