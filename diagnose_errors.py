#!/usr/bin/env python3
"""
Quick diagnostic script to identify which of the 4 common errors exist
"""

import os
import sys
import glob

def check_appicon():
    """Check if AppIcon asset exists"""
    paths = [
        "Assets.xcassets/AppIcon.appiconset/Contents.json",
        "Assets.xcassets/AppIcon.appiconset/appicon-1024.png"
    ]
    
    all_exist = all(os.path.exists(p) for p in paths)
    
    return {
        "name": "AppIcon Error",
        "exists": all_exist,
        "fix": "Run: ./fix_all_errors.sh"
    }

def check_main_file():
    """Check if main entry point files exist"""
    ios_main = find_file("PlannerApp.swift")
    watch_main = find_file("AppwatchApp.swift")
    
    return {
        "name": "Main Entry Point",
        "ios": ios_main is not None,
        "watch": watch_main is not None,
        "fix": "Check Target Membership for PlannerApp.swift and AppwatchApp.swift"
    }

def check_theme():
    """Check if Theme files exist"""
    theme_files = []
    for name in ["Theme.swift", "ThemeAndMissingTypes.swift", "Theme_Watch.swift"]:
        found = find_file(name)
        if found:
            theme_files.append(name)
    
    return {
        "name": "Theme Files",
        "found": theme_files,
        "fix": "Verify Theme.swift is in iOS target, Theme_Watch.swift in Watch target"
    }

def check_project_file():
    """Check for project.pbxproj"""
    project_files = list(glob.glob("**/*.xcodeproj/project.pbxproj", recursive=True))
    
    return {
        "name": "Project File",
        "exists": len(project_files) > 0,
        "path": project_files[0] if project_files else None
    }

def find_file(filename):
    """Find a file in current directory tree"""
    for root, dirs, files in os.walk('.'):
        if filename in files:
            return os.path.join(root, filename)
    return None

def main():
    print("🔍 RaceTrian Error Diagnostic")
    print("=" * 50)
    print()
    
    # Check 1: AppIcon
    appicon = check_appicon()
    print(f"1️⃣  {appicon['name']}")
    if appicon['exists']:
        print("   ✅ AppIcon asset catalog exists")
    else:
        print("   ❌ AppIcon asset catalog MISSING")
        print(f"   💡 Fix: {appicon['fix']}")
    print()
    
    # Check 2: Main files
    main_check = check_main_file()
    print(f"2️⃣  {main_check['name']}")
    if main_check['ios']:
        print("   ✅ iOS main file (PlannerApp.swift) exists")
    else:
        print("   ❌ iOS main file (PlannerApp.swift) NOT FOUND")
    
    if main_check['watch']:
        print("   ✅ Watch main file (AppwatchApp.swift) exists")
    else:
        print("   ⚠️  Watch main file (AppwatchApp.swift) NOT FOUND")
    
    if not main_check['ios'] or not main_check['watch']:
        print(f"   💡 Fix: {main_check['fix']}")
    print()
    
    # Check 3: Theme
    theme = check_theme()
    print(f"3️⃣  {theme['name']}")
    if theme['found']:
        for f in theme['found']:
            print(f"   ✅ Found: {f}")
    else:
        print("   ❌ No Theme files found")
        print(f"   💡 Fix: {theme['fix']}")
    print()
    
    # Check 4: Project
    project = check_project_file()
    print(f"4️⃣  {project['name']}")
    if project['exists']:
        print(f"   ✅ Project file exists: {project['path']}")
    else:
        print("   ❌ Project file NOT FOUND")
        print("   ⚠️  Make sure you're in the project directory")
    print()
    
    print("=" * 50)
    print("📊 Summary")
    print("=" * 50)
    print()
    
    issues = []
    
    if not appicon['exists']:
        issues.append("AppIcon missing")
    if not main_check['ios']:
        issues.append("PlannerApp.swift missing")
    if not theme['found']:
        issues.append("Theme files missing")
    if not project['exists']:
        issues.append("Not in project directory")
    
    if issues:
        print("⚠️  Issues Found:")
        for issue in issues:
            print(f"   • {issue}")
        print()
        print("🔧 Recommended Action:")
        print()
        print("   1. Run: chmod +x fix_all_errors.sh")
        print("   2. Run: ./fix_all_errors.sh")
        print("   3. Follow the instructions in Xcode")
        print()
    else:
        print("✅ All essential files found!")
        print()
        print("🎯 Next Steps:")
        print()
        print("   1. Open Xcode")
        print("   2. Clean Build Folder (⌘⇧K)")
        print("   3. Verify Target Membership for all files")
        print("   4. Build (⌘B)")
        print()
    
    print("=" * 50)
    print()
    print("For detailed fixes, see: FIX_4_ERRORS.md")
    print()

if __name__ == "__main__":
    main()
