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

# String.py - More robust fixing
cat > /tmp/string_patch.py << 'EOF'
import re

# Read the file
with open('BaseTools/Source/Python/Common/String.py', 'r') as f:
    content = f.read()

# Fix duplicate "from . from ." imports
content = re.sub(r'from \. from \. import', 'from . import', content)

# Ensure clean relative imports
content = re.sub(r'^import DataType$', 'from . import DataType', content, flags=re.MULTILINE)
content = re.sub(r'^import EdkLogger as EdkLogger$', 'from . import EdkLogger as EdkLogger', content, flags=re.MULTILINE)
content = re.sub(r'^import GlobalData$', 'from . import GlobalData', content, flags=re.MULTILINE)
content = re.sub(r'^from BuildToolError import \*$', 'from .BuildToolError import *', content, flags=re.MULTILINE)

# Write back
with open('BaseTools/Source/Python/Common/String.py', 'w') as f:
    f.write(content)
EOF

python /tmp/string_patch.py

# LongFilePathOs.py - Fix duplicate imports
cat > /tmp/longpath_patch.py << 'EOF'
import re

# Read the file
with open('BaseTools/Source/Python/Common/LongFilePathOs.py', 'r') as f:
    content = f.read()

# Fix duplicate "from . from ." imports
content = re.sub(r'from \. from \. import', 'from . import', content)

# Write back
with open('BaseTools/Source/Python/Common/LongFilePathOs.py', 'w') as f:
    f.write(content)
EOF

python /tmp/longpath_patch.py

# Additional Python files
sed -i.bak 's/from StringUtils import \*/from .StringUtils import */' BaseTools/Source/Python/Common/Parsing.py 2>/dev/null || true
sed -i.bak 's/import sys, codecs/import sys, codecs/' BaseTools/Source/Python/UPT/Core/FileHook.py 2>/dev/null || true

echo "6. Validating Python syntax..."
echo "Checking for common Python syntax errors..."
if python -c "import sys; sys.path.insert(0, 'BaseTools/Source/Python/Common'); import LongFilePathOs, String, Misc" 2>/dev/null; then
    echo "✅ Python files syntax check passed"
else
    echo "⚠️  Python syntax issues detected. Manual review may be needed."
fi

echo "7. Setting up build environment..."
if [ ! -f "Conf/tools_def.txt" ]; then
    echo "Setting up EDK II environment..."
    export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
    source edksetup.sh
fi

echo "8. Patching XCODE5 compiler flags in tools_def.txt..."
if [ -f "Conf/tools_def.txt" ]; then
    # Add warning suppression flags to XCODE5 X64 compiler settings for all build types
    sed -i.bak 's/-Wno-sign-compare\([^-]\)/-Wno-sign-compare -Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare\1/g' Conf/tools_def.txt
    echo "✅ XCODE5 compiler flags updated for DEBUG, NOOPT, and RELEASE builds"
else
    echo "Warning: tools_def.txt not found. Run 'source edksetup.sh' first, then apply this patch manually."
fi

echo "9. Building BaseTools..."
export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
make -C BaseTools

echo ""
echo "=== Patches Applied Successfully! ==="
echo ""
echo "To build ShellPkg now, run:"
echo "  export PATH=\"/Library/Frameworks/Python.framework/Versions/2.7/bin:\$PATH\""
echo "  source edksetup.sh"
echo ""
echo "Build options:"
echo "  build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc  # Release build"
echo "  build -a X64 -t XCODE5 -b DEBUG   -p ShellPkg/ShellPkg.dsc  # Debug build"
echo "  build -a X64 -t XCODE5 -b NOOPT   -p ShellPkg/ShellPkg.dsc  # No optimization"
echo ""
echo "Expected output: Build/Shell/{BUILD_TYPE}_XCODE5/X64/Shell.efi"

# Clean up temporary files
rm -f /tmp/misc_patch.py /tmp/string_patch.py /tmp/longpath_patch.py
