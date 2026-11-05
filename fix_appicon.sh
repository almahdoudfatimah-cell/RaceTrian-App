#!/bin/bash

# ============================================
# RaceTrian AppIcon Quick Fix
# ============================================
# This script creates the necessary asset catalog
# structure and a placeholder app icon
# ============================================

set -e  # Exit on error

echo ""
echo "🎯 RaceTrian AppIcon Quick Fix"
echo "============================================"
echo ""

# Navigate to script directory
cd "$(dirname "$0")"

# Step 1: Verify/Create directory structure
echo "📁 Step 1: Creating asset catalog structure..."

mkdir -p "Assets.xcassets/AppIcon.appiconset"
echo "   ✅ Created Assets.xcassets/AppIcon.appiconset/"

# Step 2: Create Contents.json for Assets.xcassets
echo ""
echo "📝 Step 2: Creating Contents.json files..."

cat > "Assets.xcassets/Contents.json" << 'EOFCONTENTS'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOFCONTENTS

echo "   ✅ Created Assets.xcassets/Contents.json"

# Step 3: Create Contents.json for AppIcon.appiconset
cat > "Assets.xcassets/AppIcon.appiconset/Contents.json" << 'EOFAPPICON'
{
  "images" : [
    {
      "filename" : "appicon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOFAPPICON

echo "   ✅ Created Assets.xcassets/AppIcon.appiconset/Contents.json"

# Step 4: Create placeholder icon
echo ""
echo "🎨 Step 3: Creating placeholder icon image..."

if command -v python3 &> /dev/null; then
    # Try Python method first
    python3 create_appicon.py &> /dev/null || {
        echo "   ⚠️  Python method failed, using fallback..."
        # Create a minimal 1x1 PNG that will work
        base64 -d > "Assets.xcassets/AppIcon.appiconset/appicon-1024.png" << 'EOFPNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==
EOFPNG
        echo "   ✅ Created minimal placeholder icon"
    }
else
    # Fallback: create minimal PNG
    echo "   Using base64 fallback method..."
    base64 -d > "Assets.xcassets/AppIcon.appiconset/appicon-1024.png" << 'EOFPNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==
EOFPNG
    echo "   ✅ Created minimal placeholder icon"
fi

# Step 5: Verify files exist
echo ""
echo "✓ Step 4: Verifying files..."

REQUIRED_FILES=(
    "Assets.xcassets/Contents.json"
    "Assets.xcassets/AppIcon.appiconset/Contents.json"
    "Assets.xcassets/AppIcon.appiconset/appicon-1024.png"
)

ALL_EXIST=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file"
    else
        echo "   ❌ MISSING: $file"
        ALL_EXIST=false
    fi
done

echo ""

if [ "$ALL_EXIST" = true ]; then
    echo "============================================"
    echo "✅ AppIcon structure created successfully!"
    echo "============================================"
    echo ""
    echo "📋 Next steps in Xcode:"
    echo ""
    echo "   1️⃣  Verify Assets.xcassets is in your project:"
    echo "      • If you see it in Project Navigator ✅"
    echo "      • If NOT, drag the Assets.xcassets folder into Xcode"
    echo "        and check 'RaceTrian' target when prompted"
    echo ""
    echo "   2️⃣  Check Target Membership:"
    echo "      • Click Assets.xcassets in Project Navigator"
    echo "      • Open File Inspector (⌥⌘1)"
    echo "      • Make sure 'RaceTrian' is checked ✓"
    echo ""
    echo "   3️⃣  Clean and Build:"
    echo "      • Press ⌘⇧K (Clean Build Folder)"
    echo "      • Press ⌘B (Build)"
    echo ""
    echo "   ✅ The AppIcon error should be gone!"
    echo ""
    echo "📝 Note: This creates a placeholder icon."
    echo "   For production, replace appicon-1024.png with your design."
    echo ""
else
    echo "============================================"
    echo "❌ Some files could not be created"
    echo "============================================"
    echo ""
    echo "Please check file permissions and try again."
    echo ""
    exit 1
fi

# Optional: Try to add to Xcode project automatically
if [ -f "*.xcodeproj/project.pbxproj" ]; then
    echo "💡 Tip: The asset catalog has been created on disk."
    echo "   If Xcode doesn't see it automatically, drag it into Xcode."
    echo ""
fi
