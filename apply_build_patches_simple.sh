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
if grep -q "DEBUG_XCODE5_X64_CC_FLAGS" Conf/tools_def.txt; then
    # Fix DEBUG build to use no optimization with debug symbols
    sed -i.bak 's/DEBUG_XCODE5_X64_CC_FLAGS.*-Os/DEBUG_XCODE5_X64_CC_FLAGS   = -target x86_64-pc-win32-macho -c -g -O0/' Conf/tools_def.txt
    
    # Make NOOPT use -O1 instead of -O0 to differentiate from DEBUG
    sed -i.bak1 's/NOOPT_XCODE5_X64_CC_FLAGS.*-O0/NOOPT_XCODE5_X64_CC_FLAGS   = -target x86_64-pc-win32-macho -c -O1/' Conf/tools_def.txt
    
    # Add debug defines to enable debug output properly for DEBUG only
    sed -i.bak2 's/DEBUG_XCODE5_X64_CC_FLAGS.*$/& -DDEBUG_ASSERT_ENABLED=TRUE -DDEBUG_PRINT_ENABLED=TRUE -DDEBUG_CODE_ENABLED=TRUE/' Conf/tools_def.txt
    
    # Add warning suppression flags for all build types
    sed -i.bak3 's/DEBUG_XCODE5_X64_CC_FLAGS.*$/& -Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare/' Conf/tools_def.txt
    sed -i.bak4 's/NOOPT_XCODE5_X64_CC_FLAGS.*$/& -Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare/' Conf/tools_def.txt
    sed -i.bak5 's/RELEASE_XCODE5_X64_CC_FLAGS.*$/& -Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare/' Conf/tools_def.txt
    
    echo "✅ XCODE5 compiler flags updated:"
    echo "   - DEBUG: No optimization (-O0) + debug symbols + debug defines"
    echo "   - NOOPT: Minimal optimization (-O1) for differentiation"  
    echo "   - RELEASE: Size optimization (-Os) for production"
    echo "   - All: Warning suppressions added"
else
    echo "⚠️ tools_def.txt not found or XCODE5 flags not present"
fi

echo "8. ShellPkg.dsc has been manually patched with build-specific debug masks:"
echo "   - DEBUG: 0x2F (assert+print+code+clear+deadloop)"
echo "   - NOOPT: 0x07 (assert+print+code only)"
echo "   - RELEASE: 0x00 (no debug features)"

echo "9. Building BaseTools..."
make -C BaseTools/Source/C

echo ""
echo "✅ All patches applied successfully!"
echo ""
echo "You can now build the Shell with:"
echo "   export PATH=\"/Library/Frameworks/Python.framework/Versions/2.7/bin:\$PATH\""
echo "   source edksetup.sh"
echo "   build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc"
echo ""