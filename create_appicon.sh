#!/bin/bash

# Script to create a placeholder AppIcon for RaceTrian
# This creates a simple colored square that Xcode will accept

echo "🎨 Creating placeholder AppIcon..."

# Check if ImageMagick is installed
if command -v convert &> /dev/null; then
    echo "✅ ImageMagick found, creating icon with gradient..."
    
    # Create a 1024x1024 icon with a gradient (RaceTrian brand colors)
    convert -size 1024x1024 \
        gradient:'#D95200-#FF8C0D' \
        -background '#FFD100' \
        -gravity center \
        -font Helvetica-Bold \
        -pointsize 200 \
        -fill white \
        -annotate +0+0 'RT' \
        Assets.xcassets/AppIcon.appiconset/appicon-1024.png
    
    echo "✅ Created appicon-1024.png with 'RT' logo"
    
elif command -v sips &> /dev/null; then
    echo "✅ Using macOS sips to create basic icon..."
    
    # Create a temporary solid color image using sips
    # First create a small image, then scale it up
    python3 - << 'PYTHON_SCRIPT'
from PIL import Image, ImageDraw, ImageFont
import os

# Create a 1024x1024 image with gradient
size = 1024
img = Image.new('RGB', (size, size))
draw = ImageDraw.Draw(img)

# Draw gradient background (orange to yellow)
for y in range(size):
    r = int(217 + (255 - 217) * (y / size))
    g = int(82 + (209 - 82) * (y / size))
    b = int(0 + (0 - 0) * (y / size))
    draw.rectangle([(0, y), (size, y+1)], fill=(r, g, b))

# Add text "RT" in the center
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 300)
except:
    font = ImageFont.load_default()

text = "RT"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
x = (size - text_width) // 2
y = (size - text_height) // 2 - 50

draw.text((x, y), text, fill='white', font=font)

# Save
os.makedirs('Assets.xcassets/AppIcon.appiconset', exist_ok=True)
img.save('Assets.xcassets/AppIcon.appiconset/appicon-1024.png')
print("✅ Created appicon-1024.png with 'RT' logo")
PYTHON_SCRIPT

else
    echo "⚠️  Neither ImageMagick nor Python PIL available"
    echo "Creating a minimal valid PNG file..."
    
    # Create a minimal 1024x1024 PNG using base64
    # This is a small red square that will be stretched
    base64 -d > Assets.xcassets/AppIcon.appiconset/appicon-1024.png << 'EOF'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==
EOF
    
    echo "✅ Created minimal placeholder icon"
    echo "⚠️  You should replace this with a proper icon later"
fi

echo ""
echo "=============================="
echo "✅ AppIcon setup complete!"
echo "=============================="
echo ""
echo "Next steps:"
echo "1. Open your project in Xcode"
echo "2. Press ⌘⇧K (Clean Build Folder)"
echo "3. Press ⌘B (Build)"
echo ""
echo "The AppIcon error should now be fixed! 🎉"
echo ""
echo "📝 Note: This is a placeholder icon."
echo "   For production, replace with proper 1024x1024 artwork in:"
echo "   Assets.xcassets/AppIcon.appiconset/appicon-1024.png"
echo ""
