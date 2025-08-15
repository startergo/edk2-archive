#!/bin/bash

# EDK II Reset and Patch Script for macOS (Apple Silicon)
# This script resets patched files to original state and applies fresh patches

set -e

echo "=== EDK II Reset and Patch Script ==="
echo "Resetting files to original state and applying fresh patches..."

# Check if we're in the right directory
if [ ! -f "edksetup.sh" ]; then
    echo "Error: This script must be run from the EDK II root directory"
    exit 1
fi

echo "1. Resetting modified files to original state..."

# Reset the main files that get patched
git checkout HEAD -- BaseTools/Source/C/GNUmakefile 2>/dev/null || echo "  GNUmakefile was not modified"
git checkout HEAD -- BaseTools/Source/C/Include/AArch64/ProcessorBind.h 2>/dev/null || echo "  ProcessorBind.h was not modified"
git checkout HEAD -- BaseTools/Source/C/Common/FvLib.c 2>/dev/null || echo "  FvLib.c was not modified"
git checkout HEAD -- BaseTools/Source/C/VfrCompile/VfrUtilityLib.cpp 2>/dev/null || echo "  VfrUtilityLib.cpp was not modified"

# Clean up any backup files
rm -f BaseTools/Source/C/GNUmakefile.bak* 2>/dev/null || true
rm -f BaseTools/Source/C/Include/AArch64/ProcessorBind.h.bak* 2>/dev/null || true
rm -f BaseTools/Source/C/Common/FvLib.c.bak* 2>/dev/null || true
rm -f BaseTools/Source/C/VfrCompile/VfrUtilityLib.cpp.bak* 2>/dev/null || true

# Clean up build artifacts and configuration
echo "2. Cleaning build artifacts..."
rm -rf Build/ 2>/dev/null || true
rm -f Conf/build_rule.txt Conf/target.txt Conf/tools_def.txt 2>/dev/null || true

echo "3. Applying fresh patches..."

# Now run the simplified patch script
if [ -f "apply_build_patches_simple.sh" ]; then
    ./apply_build_patches_simple.sh
else
    echo "Error: apply_build_patches_simple.sh not found!"
    exit 1
fi

echo ""
echo "✅ Reset and patch completed successfully!"
echo ""
echo "You can now build the Shell with:"
echo "   export PATH=\"/Library/Frameworks/Python.framework/Versions/2.7/bin:\$PATH\""
echo "   source edksetup.sh"
echo "   build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc"
echo ""
