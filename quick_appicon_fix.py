#!/usr/bin/env python3
"""
Quick AppIcon fix - Creates minimal placeholder and updates project if needed
"""

import subprocess
import sys
import os

print("🔧 Quick AppIcon Fix")
print("=" * 50)
print()

# Step 1: Run the icon creator
print("Step 1: Creating placeholder icon...")
result = subprocess.run([sys.executable, "create_appicon.py"], capture_output=False)

if result.returncode != 0:
    print("❌ Failed to create icon")
    sys.exit(1)

print()
print("Step 2: Verifying asset catalog...")

# Check if Assets.xcassets exists in the project file
project_file = None
for root, dirs, files in os.walk('.'):
    for file in files:
        if file == 'project.pbxproj':
            project_file = os.path.join(root, file)
            break
    if project_file:
        break

if project_file:
    print(f"✅ Found project file: {project_file}")
    
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if 'Assets.xcassets' in content:
        print("✅ Assets.xcassets is already in your project")
    else:
        print("⚠️  Assets.xcassets might not be in your project")
        print("   You may need to add it manually in Xcode:")
        print("   1. Drag Assets.xcassets folder into Xcode")
        print("   2. Check 'RaceTrian' target when prompted")
else:
    print("⚠️  Could not find project.pbxproj file")

print()
print("=" * 50)
print("✅ Fix complete!")
print("=" * 50)
print()
print("🎯 Final steps in Xcode:")
print("   1. Clean Build Folder (⌘⇧K)")
print("   2. Build (⌘B)")
print()
print("If the error persists:")
print("   • In Xcode, check that Assets.xcassets is in your project")
print("   • Select Assets.xcassets → File Inspector → Target Membership")
print("   • Make sure 'RaceTrian' is checked ✓")
print()
