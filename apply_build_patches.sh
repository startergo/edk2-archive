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
sed -i.bak '/ifneq.*aarch64/a\
  ifneq (,$(strip $(filter $(uname_m), arm64)))\
    ARCH=AARCH64\
  endif' BaseTools/Source/C/GNUmakefile

echo "2. Patching BaseTools/Source/C/Include/AArch64/ProcessorBind.h..."
sed -i.bak 's/#define UINT8_MAX 0xff/#ifndef UINT8_MAX\
  #define UINT8_MAX 0xff\
  #endif/' BaseTools/Source/C/Include/AArch64/ProcessorBind.h

echo "3. Patching BaseTools/Source/C/Common/FvLib.c..."
sed -i.bak 's/(-1 << 3)/(~0x07)/g' BaseTools/Source/C/Common/FvLib.c
sed -i.bak 's/(-1 << 2)/(~0x03)/g' BaseTools/Source/C/Common/FvLib.c

echo "4. Patching BaseTools/Source/C/VfrCompile/VfrUtilityLib.cpp..."
sed -i.bak "s/if (mStringFileName == '\\\\0' )/if (mStringFileName == NULL || mStringFileName[0] == '\\\\0' )/" BaseTools/Source/C/VfrCompile/VfrUtilityLib.cpp

echo "5. Patching Python files for Python 2/3 compatibility..."

# EdkLogger.py
sed -i.bak 's/from  BuildToolError import \*/from .BuildToolError import */' BaseTools/Source/Python/Common/EdkLogger.py

# LongFilePathOs.py
sed -i.bak 's/import LongFilePathOsPath/from . import LongFilePathOsPath/' BaseTools/Source/Python/Common/LongFilePathOs.py
sed -i.bak 's/mode=0777/mode=0o777/' BaseTools/Source/Python/Common/LongFilePathOs.py

# Misc.py
cat > /tmp/misc_patch.py << 'EOF'
import sys

# Read the file
with open('BaseTools/Source/Python/Common/Misc.py', 'r') as f:
    content = f.read()

# Apply patches
content = content.replace('import thread', '''try:
    import thread
except ImportError:
    import _thread as thread''')

content = content.replace('import cPickle', '''try:
    import cPickle
except ImportError:
    import pickle as cPickle''')

# Write back
with open('BaseTools/Source/Python/Common/Misc.py', 'w') as f:
    f.write(content)
EOF

python /tmp/misc_patch.py

# String.py
sed -i.bak 's/import DataType/from . import DataType/' BaseTools/Source/Python/Common/String.py
sed -i.bak 's/import EdkLogger as EdkLogger/from . import EdkLogger as EdkLogger/' BaseTools/Source/Python/Common/String.py
sed -i.bak 's/import GlobalData/from . import GlobalData/' BaseTools/Source/Python/Common/String.py
sed -i.bak 's/from BuildToolError import \*/from .BuildToolError import */' BaseTools/Source/Python/Common/String.py

# Additional Python files
sed -i.bak 's/from StringUtils import \*/from .StringUtils import */' BaseTools/Source/Python/Common/Parsing.py 2>/dev/null || true
sed -i.bak 's/import sys, codecs/import sys, codecs/' BaseTools/Source/Python/UPT/Core/FileHook.py 2>/dev/null || true

echo "6. Setting up build environment..."
if [ ! -f "Conf/tools_def.txt" ]; then
    echo "Setting up EDK II environment..."
    export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
    source edksetup.sh
fi

echo "7. Patching XCODE5 compiler flags in tools_def.txt..."
if [ -f "Conf/tools_def.txt" ]; then
    # Add warning suppression flags to XCODE5 X64 compiler settings
    sed -i.bak 's/-Wno-sign-compare/-Wno-sign-compare -Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare/g' Conf/tools_def.txt
else
    echo "Warning: tools_def.txt not found. Run 'source edksetup.sh' first, then apply this patch manually."
fi

echo "8. Building BaseTools..."
export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
make -C BaseTools

echo ""
echo "=== Patches Applied Successfully! ==="
echo ""
echo "To build ShellPkg now, run:"
echo "  export PATH=\"/Library/Frameworks/Python.framework/Versions/2.7/bin:\$PATH\""
echo "  source edksetup.sh"
echo "  build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc"
echo ""
echo "Expected output: Build/Shell/RELEASE_XCODE5/X64/Shell.efi"

# Clean up temporary files
rm -f /tmp/misc_patch.py
