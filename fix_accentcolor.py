#!/usr/bin/env python3
"""
Fix AccentColor Error in Xcode Project
Creates the AccentColor.colorset in Media.xcassets
"""

import os
import json
from pathlib import Path

def main():
    print("🎨 AccentColor Fix Script")
    print("=" * 50)
    print()
    
    # Find Media.xcassets
    media_assets = Path('Media.xcassets')
    
    if not media_assets.exists():
        print("❌ Error: Media.xcassets not found in current directory")
        print("   Please run this from your project root directory")
        print("   (where Media.xcassets is located)")
        return 1
    
    print(f"✅ Found: {media_assets}")
    print()
    
    # Create AccentColor.colorset directory
    accent_color_dir = media_assets / 'AccentColor.colorset'
    
    if accent_color_dir.exists():
        print("⚠️  AccentColor.colorset already exists!")
        print("   The error might be something else.")
        print()
        response = input("   Do you want to recreate it? (y/n): ")
        if response.lower() != 'y':
            print("   Cancelled.")
            return 0
        print()
    
    # Create the directory
    accent_color_dir.mkdir(exist_ok=True)
    print(f"✅ Created: {accent_color_dir}")
    
    # Create Contents.json for AccentColor
    contents_json = {
        "colors": [
            {
                "idiom": "universal",
                "color": {
                    "color-space": "srgb",
                    "components": {
                        "red": "1.000",
                        "green": "0.820",
                        "blue": "0.000",
                        "alpha": "1.000"
                    }
                }
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    contents_file = accent_color_dir / 'Contents.json'
    
    with open(contents_file, 'w', encoding='utf-8') as f:
        json.dump(contents_json, f, indent=2)
    
    print(f"✅ Created: {contents_file}")
    print()
    print("   Color set to: Orange/Yellow (#FFD100)")
    print()
    
    # Update Media.xcassets Contents.json if needed
    main_contents = media_assets / 'Contents.json'
    
    if not main_contents.exists():
        # Create a basic Contents.json for Media.xcassets
        main_json = {
            "info": {
                "author": "xcode",
                "version": 1
            }
        }
        
        with open(main_contents, 'w', encoding='utf-8') as f:
            json.dump(main_json, f, indent=2)
        
        print(f"✅ Created: {main_contents}")
    else:
        print(f"✅ Found: {main_contents}")
    
    print()
    print("=" * 50)
    print("✅ AccentColor fix complete!")
    print("=" * 50)
    print()
    print("📋 Next steps:")
    print()
    print("1. Open Xcode")
    print("2. Product → Clean Build Folder (⌘⇧K)")
    print("3. Product → Build (⌘B)")
    print()
    print("✅ The AccentColor error should be gone!")
    print()
    print("💡 You can change the color in Xcode:")
    print("   • Click Media.xcassets in Project Navigator")
    print("   • Click AccentColor")
    print("   • Change color in the right panel")
    print()
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
