#!/bin/bash

# EDK II Build Patch Validation Script
# Verifies that all necessary patches have been applied

echo "=== EDK II Build Patch Validation ==="

ERRORS=0

# Check Apple Silicon fix
if grep -q "arm64" BaseTools/Source/C/GNUmakefile; then
    echo "✅ Apple Silicon (arm64) detection patch applied"
else
    echo "❌ Missing Apple Silicon detection patch in GNUmakefile"
    ERRORS=$((ERRORS + 1))
fi

# Check UINT8_MAX fix
if grep -q "#ifndef UINT8_MAX" BaseTools/Source/C/Include/AArch64/ProcessorBind.h; then
    echo "✅ UINT8_MAX redefinition fix applied"
else
    echo "❌ Missing UINT8_MAX redefinition fix"
    ERRORS=$((ERRORS + 1))
fi

# Check bitwise alignment fixes
if grep -q "(~0x07)" BaseTools/Source/C/Common/FvLib.c; then
    echo "✅ Bitwise alignment fixes applied in FvLib.c"
else
    echo "❌ Missing bitwise alignment fixes in FvLib.c"
    ERRORS=$((ERRORS + 1))
fi

# Check pointer comparison fix
if grep -q "mStringFileName == NULL" BaseTools/Source/C/VfrCompile/VfrUtilityLib.cpp; then
    echo "✅ Pointer comparison fix applied in VfrUtilityLib.cpp"
else
    echo "❌ Missing pointer comparison fix in VfrUtilityLib.cpp"
    ERRORS=$((ERRORS + 1))
fi

# Check Python import fixes
if grep -q "from .BuildToolError import" BaseTools/Source/Python/Common/EdkLogger.py; then
    echo "✅ Python relative import fixes applied"
else
    echo "❌ Missing Python relative import fixes"
    ERRORS=$((ERRORS + 1))
fi

# Check compiler flags (if tools_def.txt exists)
if [ -f "Conf/tools_def.txt" ]; then
    if grep -q "Wno-pointer-compare" Conf/tools_def.txt; then
        echo "✅ XCODE5 compiler warning suppression flags applied"
    else
        echo "❌ Missing XCODE5 compiler warning suppression flags"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "⚠️  tools_def.txt not found (run 'source edksetup.sh' first)"
fi

# Check Python 2.7 availability
if command -v python2.7 >/dev/null 2>&1; then
    echo "✅ Python 2.7 available"
else
    echo "❌ Python 2.7 not found in PATH"
    ERRORS=$((ERRORS + 1))
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "🎉 All patches validated successfully!"
    echo "Ready to build with: build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc"
    exit 0
else
    echo "❌ $ERRORS validation errors found. Please apply missing patches."
    exit 1
fi
