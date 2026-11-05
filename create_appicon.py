#!/usr/bin/env python3
"""
Create a placeholder AppIcon for RaceTrian
This script generates a simple 1024x1024 PNG icon
"""

import os
import sys

def create_placeholder_icon():
    """Create a simple placeholder icon using PIL or a fallback method"""
    
    icon_dir = "Assets.xcassets/AppIcon.appiconset"
    icon_path = os.path.join(icon_dir, "appicon-1024.png")
    
    # Ensure directory exists
    os.makedirs(icon_dir, exist_ok=True)
    
    print("🎨 Creating placeholder AppIcon...")
    
    try:
        from PIL import Image, ImageDraw, ImageFont
        
        # Create a 1024x1024 image
        size = 1024
        img = Image.new('RGB', (size, size))
        draw = ImageDraw.Draw(img)
        
        # Draw gradient background (RaceTrian brand colors: orange to yellow)
        for y in range(size):
            # Gradient from #D95200 (217, 82, 0) to #FFD100 (255, 209, 0)
            r = int(217 + (255 - 217) * (y / size))
            g = int(82 + (209 - 82) * (y / size))
            b = 0
            draw.rectangle([(0, y), (size, y+1)], fill=(r, g, b))
        
        # Add "RT" text in the center
        try:
            # Try to use a system font
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 300)
        except:
            try:
                font = ImageFont.truetype("/System/Library/Fonts/SF-Compact-Display-Bold.otf", 300)
            except:
                # Fallback to default font
                font = ImageFont.load_default()
        
        text = "RT"
        
        # Get text size and center it
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        x = (size - text_width) // 2
        y = (size - text_height) // 2 - 50
        
        # Draw text with shadow for depth
        shadow_offset = 4
        draw.text((x + shadow_offset, y + shadow_offset), text, fill=(0, 0, 0, 128), font=font)
        draw.text((x, y), text, fill='white', font=font)
        
        # Save the icon
        img.save(icon_path, 'PNG')
        
        print(f"✅ Created {icon_path} with 'RT' logo")
        print(f"   Size: 1024x1024 pixels")
        return True
        
    except ImportError:
        print("⚠️  PIL (Pillow) not available, using fallback method...")
        return create_simple_png_fallback(icon_path)

def create_simple_png_fallback(icon_path):
    """Create a minimal valid PNG as fallback"""
    
    # This creates a simple 1x1 orange pixel PNG
    # Xcode will accept this, though it's not pretty
    png_data = bytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
        0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, 0x00,  # Width: 1024, Height: 1024
        0x08, 0x02, 0x00, 0x00, 0x00, 0x60, 0x1D, 0x87,  # RGB, no compression
        0xF6, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  # IDAT chunk (minimal data)
        0x54, 0x78, 0x9C, 0x62, 0xF8, 0xCF, 0xC0, 0x00,  # Compressed pixel data
        0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x03,
        0xCB, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,  # IEND chunk
        0x44, 0xAE, 0x42, 0x60, 0x82
    ])
    
    with open(icon_path, 'wb') as f:
        f.write(png_data)
    
    print(f"✅ Created minimal placeholder: {icon_path}")
    print("   ⚠️  This is a basic 1x1 pixel placeholder")
    return True

def verify_asset_catalog():
    """Verify that the asset catalog structure is correct"""
    
    required_files = [
        "Assets.xcassets/Contents.json",
        "Assets.xcassets/AppIcon.appiconset/Contents.json"
    ]
    
    all_exist = True
    for file in required_files:
        if not os.path.exists(file):
            print(f"❌ Missing: {file}")
            all_exist = False
    
    return all_exist

def main():
    print("🎯 RaceTrian AppIcon Creator")
    print("=" * 40)
    print()
    
    # Verify asset catalog structure exists
    if not verify_asset_catalog():
        print()
        print("⚠️  Asset catalog structure not found!")
        print("   Make sure Contents.json files exist")
        return 1
    
    # Create the icon
    if create_placeholder_icon():
        print()
        print("=" * 40)
        print("✅ AppIcon setup complete!")
        print("=" * 40)
        print()
        print("Next steps:")
        print("1. Open your project in Xcode")
        print("2. Press ⌘⇧K (Clean Build Folder)")
        print("3. Press ⌘B (Build)")
        print()
        print("The AppIcon error should now be fixed! 🎉")
        print()
        print("📝 Note: This is a placeholder icon.")
        print("   For production, replace with proper artwork:")
        print("   Assets.xcassets/AppIcon.appiconset/appicon-1024.png")
        print()
        return 0
    else:
        print()
        print("❌ Failed to create icon")
        return 1

if __name__ == "__main__":
    sys.exit(main())
