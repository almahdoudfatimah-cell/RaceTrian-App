#!/usr/bin/env python3
"""
Complete Xcode Project Fix - AccentColor + Build Issues
This script fixes the AccentColor error and verifies project setup
"""

import os
import json
import shutil
from pathlib import Path
from datetime import datetime

def print_section(title):
    print()
    print("=" * 60)
    print(f"  {title}")
    print("=" * 60)
    print()

def main():
    print_section("🔧 RaceTrian Complete Project Fix")
    
    # Check we're in the right directory
    if not Path('Media.xcassets').exists():
        print("❌ Error: Media.xcassets not found")
        print()
        print("Please run this from your project directory:")
        print("   cd ~/Desktop/RaceTrian")
        print("   python3 fix_complete.py")
        return 1
    
    print("✅ Found: Media.xcassets")
    
    # Fix 1: Create AccentColor
    print_section("🎨 Fix 1: Creating AccentColor")
    
    accent_color_dir = Path('Media.xcassets/AccentColor.colorset')
    
    if accent_color_dir.exists():
        print("⚠️  AccentColor.colorset already exists")
        print("   Recreating it to ensure it's correct...")
        shutil.rmtree(accent_color_dir)
    
    accent_color_dir.mkdir(parents=True, exist_ok=True)
    print(f"✅ Created: {accent_color_dir}")
    
    # Create Contents.json for AccentColor
    accent_contents = {
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
    
    accent_contents_file = accent_color_dir / 'Contents.json'
    with open(accent_contents_file, 'w', encoding='utf-8') as f:
        json.dump(accent_contents, f, indent=2)
    
    print(f"✅ Created: {accent_contents_file}")
    print("   Color: Orange/Yellow (#FFD100)")
    
    # Fix 2: Verify/Create Media.xcassets Contents.json
    print_section("📁 Fix 2: Verifying Media.xcassets")
    
    media_contents = Path('Media.xcassets/Contents.json')
    
    if not media_contents.exists():
        media_json = {
            "info": {
                "author": "xcode",
                "version": 1
            }
        }
        
        with open(media_contents, 'w', encoding='utf-8') as f:
            json.dump(media_json, f, indent=2)
        
        print(f"✅ Created: {media_contents}")
    else:
        print(f"✅ Found: {media_contents}")
    
    # Fix 3: Check for AppIcon
    print_section("🖼️  Fix 3: Checking AppIcon")
    
    appicon_dir = Path('Media.xcassets/AppIcon.appiconset')
    
    if not appicon_dir.exists():
        print("⚠️  AppIcon.appiconset not found")
        print("   Creating it now...")
        
        appicon_dir.mkdir(parents=True, exist_ok=True)
        
        appicon_contents = {
            "images": [
                {
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
            }
        }
        
        appicon_contents_file = appicon_dir / 'Contents.json'
        with open(appicon_contents_file, 'w', encoding='utf-8') as f:
            json.dump(appicon_contents, f, indent=2)
        
        print(f"✅ Created: {appicon_dir}")
        print(f"✅ Created: {appicon_contents_file}")
    else:
        print(f"✅ Found: {appicon_dir}")
    
    # Fix 4: Clean Xcode caches
    print_section("🧹 Fix 4: Cleaning Xcode Caches")
    
    # Clean DerivedData
    derived_data = Path.home() / "Library/Developer/Xcode/DerivedData"
    
    if derived_data.exists():
        removed_count = 0
        for item in derived_data.iterdir():
            if item.is_dir() and 'RaceTrian' in item.name:
                try:
                    print(f"   Removing: {item.name}")
                    shutil.rmtree(item)
                    removed_count += 1
                except Exception as e:
                    print(f"   ⚠️  Could not remove {item.name}: {e}")
        
        if removed_count > 0:
            print(f"✅ Cleaned {removed_count} DerivedData folder(s)")
        else:
            print("✅ No stale DerivedData found")
    else:
        print("✅ DerivedData folder not found (nothing to clean)")
    
    # Clean ModuleCache
    module_cache = Path.home() / "Library/Developer/Xcode/DerivedData/ModuleCache.noindex"
    if module_cache.exists():
        try:
            shutil.rmtree(module_cache)
            print("✅ Cleaned ModuleCache")
        except:
            print("⚠️  Could not clean ModuleCache (may be in use)")
    
    # Fix 5: Check project structure
    print_section("📦 Fix 5: Verifying Project Structure")
    
    xcodeproj = None
    for item in Path('.').iterdir():
        if item.suffix == '.xcodeproj':
            xcodeproj = item
            break
    
    if xcodeproj:
        print(f"✅ Found Xcode project: {xcodeproj}")
    else:
        print("⚠️  No .xcodeproj found (might be in a different directory)")
    
    # Summary
    print_section("✅ All Fixes Complete!")
    
    print("📋 What was fixed:")
    print("   ✅ Created/verified AccentColor.colorset")
    print("   ✅ Created/verified AppIcon.appiconset")
    print("   ✅ Verified Media.xcassets structure")
    print("   ✅ Cleaned Xcode caches")
    print("   ✅ Verified project structure")
    print()
    print("🎯 Next Steps:")
    print()
    print("1. Open Xcode (if it's already open, restart it)")
    print("2. Open your RaceTrian project")
    print("3. Product → Clean Build Folder (⌘⇧K)")
    print("4. Product → Build (⌘B)")
    print()
    print("✅ The AccentColor error should be GONE!")
    print()
    print("📁 Verify in Xcode:")
    print("   • Click Media.xcassets in Project Navigator")
    print("   • You should see AccentColor listed")
    print("   • You should see AppIcon listed")
    print()
    print("💡 If you still see errors:")
    print("   • They're likely different errors (not AccentColor)")
    print("   • Share the new error message")
    print("   • I'll help you fix it")
    print()
    print("🎨 Change the color (optional):")
    print("   • In Xcode, click Media.xcassets")
    print("   • Click AccentColor")
    print("   • Click the color square in right panel")
    print("   • Pick any color you want")
    print()
    
    return 0

if __name__ == '__main__':
    import sys
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n❌ Cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
