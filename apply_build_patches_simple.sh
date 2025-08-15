#!/bin/bash

# EDK II ShellPkg Build Patch Script for macOS (Apple Silicon)
# This script applies all necessary patches to build EDK II ShellPkg successfully

set -e

echo "=== EDK II ShellPkg Build Patcher ==="
echo "Applying patches for macOS Apple Silicon build..."

# Check if we're in the right directory
if [ ! -f "edksetup.sh" ]; then
    echo "Error: This script must be run from the EDK II root directory"
    exit 1
fi

echo "1. Patching BaseTools/Source/C/GNUmakefile for Apple Silicon..."
# Create a backup
cp BaseTools/Source/C/GNUmakefile BaseTools/Source/C/GNUmakefile.orig

# Use a more direct approach with awk
awk '
/ifneq.*findstring aarch64/ { 
    print; 
    getline; print;  # print the ARCH=AARCH64 line
    getline; print;  # print the endif line
    # Add arm64 detection
    print "  ifneq (,$(strip $(filter $(uname_m), arm64)))"
    print "    ARCH=AARCH64"
    print "  endif"
    next 
}
/ifneq.*findstring arm/ && !/arm64/ && !/aarch64/ { 
    print "  ifneq (,$(findstring arm,$(uname_m)))"
    print "    ifeq ($(findstring arm64,$(uname_m)),)"
    getline;  # skip the original ARCH=ARM line
    print "      ARCH=ARM"
    print "    endif"
    getline; print;  # print the endif
    next 
}
{ print }
' BaseTools/Source/C/GNUmakefile.orig > BaseTools/Source/C/GNUmakefile

echo "✅ GNUmakefile patched successfully"

echo "2. Patching BaseTools/Source/C/Include/AArch64/ProcessorBind.h..."
sed -i.bak 's/#define UINT8_MAX 0xff/#ifndef UINT8_MAX\
  #define UINT8_MAX 0xff\
  #endif/' BaseTools/Source/C/Include/AArch64/ProcessorBind.h

echo "3. Patching BaseTools/Source/C/Common/FvLib.c..."
sed -i.bak 's/(-1 << 3)/(~0x07)/g' BaseTools/Source/C/Common/FvLib.c
sed -i.bak 's/(-1 << 2)/(~0x03)/g' BaseTools/Source/C/Common/FvLib.c

echo "4. Patching BaseTools/Source/C/VfrCompile/VfrUtilityLib.cpp..."
sed -i.bak "s/if (mStringFileName == '\\\\0' )/if (mStringFileName == NULL || mStringFileName[0] == '\\\\0' )/" BaseTools/Source/C/VfrCompile/VfrUtilityLib.cpp

echo "5. Skipping complex Python patches to avoid corruption..."
echo "   (The build system works with Python 2.7 without these patches)"

echo "6. Setting up build environment..."
export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
source edksetup.sh

echo "7. Patching XCODE5 compiler flags in tools_def.txt..."
if grep -q "XCODE5_X64_CC_FLAGS" Conf/tools_def.txt; then
    # Add warning suppression flags for XCODE5
    sed -i.bak 's/XCODE5_X64_CC_FLAGS.*$/& -Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare/' Conf/tools_def.txt
    sed -i.bak2 's/XCODE5_IA32_CC_FLAGS.*$/& -Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare/' Conf/tools_def.txt
    echo "✅ XCODE5 compiler flags updated for DEBUG, NOOPT, and RELEASE builds"
else
    echo "⚠️ tools_def.txt not found or XCODE5 flags not present"
fi

echo "8. Building BaseTools..."
make -C BaseTools/Source/C

echo ""
echo "✅ All patches applied successfully!"
echo ""
echo "You can now build the Shell with:"
echo "   export PATH=\"/Library/Frameworks/Python.framework/Versions/2.7/bin:\$PATH\""
echo "   source edksetup.sh"
echo "   build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc"
echo ""
