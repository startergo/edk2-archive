# EDK II ShellPkg Build Patches for macOS (Apple Silicon)

This document lists all the patches/changes required to successfully build the EDK II ShellPkg on macOS with Apple Silicon (arm64) using the XCODE5 toolchain.

## Overview

The following files need to be patched to build EDK II ShellPkg successfully:

1. **BaseTools C Code Fixes** (Apple Silicon + Compiler Compatibility)
2. **Python 2/3 Compatibility Fixes** 
3. **XCODE5 Toolchain Compiler Flags**

## Required Environment

- **macOS**: Apple Silicon or Intel
- **Python**: 2.7 (required for legacy build system)
- **Xcode**: Command Line Tools installed
- **Build Command**: 
  ```bash
  export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
  source edksetup.sh
  build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc
  ```

---

## 1. BaseTools/Source/C/GNUmakefile

**Purpose**: Fix Apple Silicon (arm64) architecture detection

```diff
@@ -28,6 +28,9 @@ ifndef ARCH
   ifneq (,$(findstring aarch64,$(uname_m)))
     ARCH=AARCH64
   endif
+  ifneq (,$(strip $(filter $(uname_m), arm64)))
+    ARCH=AARCH64
+  endif
   ifneq (,$(findstring arm,$(uname_m)))
     ARCH=ARM
   endif
```

**Explanation**: Apple Silicon reports `arm64` instead of `aarch64`, so we need to map it correctly.

---

## 2. BaseTools/Source/C/Include/AArch64/ProcessorBind.h

**Purpose**: Fix UINT8_MAX redefinition error

```diff
@@ -61,7 +61,9 @@
   typedef char                CHAR8;
   typedef signed char         INT8;
 
+  #ifndef UINT8_MAX
   #define UINT8_MAX 0xff
+  #endif
 #endif
```

**Explanation**: Prevent macro redefinition when system headers already define UINT8_MAX.

---

## 3. BaseTools/Source/C/Common/FvLib.c

**Purpose**: Fix bitwise alignment operations for modern compilers

```diff
@@ -194,7 +194,7 @@ Returns:
   //
   // Get next file, compensate for 8 byte alignment if necessary.
   //
-  *NextFile = (EFI_FFS_FILE_HEADER *) ((((UINTN) CurrentFile - (UINTN) mFvHeader + GetFfsFileLength(CurrentFile) + 0x07) & (-1 << 3)) + (UINT8 *) mFvHeader);
+  *NextFile = (EFI_FFS_FILE_HEADER *) ((((UINTN) CurrentFile - (UINTN) mFvHeader + GetFfsFileLength(CurrentFile) + 0x07) & (~0x07)) + (UINT8 *) mFvHeader);

@@ -479,7 +479,7 @@ Returns:
     //
     // Find next section (including compensating for alignment issues.
     //
-    CurrentSection.CommonHeader = (EFI_COMMON_SECTION_HEADER *) ((((UINTN) CurrentSection.CommonHeader) + GetSectionFileLength(CurrentSection.CommonHeader) + 0x03) & (-1 << 2));
+    CurrentSection.CommonHeader = (EFI_COMMON_SECTION_HEADER *) ((((UINTN) CurrentSection.CommonHeader) + GetSectionFileLength(CurrentSection.CommonHeader) + 0x03) & (~0x03));
```

**Explanation**: Replace `(-1 << N)` with `(~0xNN)` for proper bitwise alignment masks.

---

## 4. BaseTools/Source/C/VfrCompile/VfrUtilityLib.cpp

**Purpose**: Fix pointer comparison issue

```diff
@@ -3284,7 +3284,7 @@ CVfrStringDB::GetVarStoreNameFormStringId (
   UINT8       BlockType;
   EFI_HII_STRING_PACKAGE_HDR *PkgHeader;
   
-  if (mStringFileName == '\0' ) {
+  if (mStringFileName == NULL || mStringFileName[0] == '\0' ) {
     return NULL;
   }
```

**Explanation**: Fix comparison between pointer and character literal.

---

## 5. Python 2/3 Compatibility Fixes

### BaseTools/Source/Python/Common/EdkLogger.py

```diff
-from  BuildToolError import *
+from .BuildToolError import *
```

### BaseTools/Source/Python/Common/LongFilePathOs.py

```diff
-import LongFilePathOsPath
+from . import LongFilePathOsPath

-def makedirs(name, mode=0777):
+def makedirs(name, mode=0o777):
```

### BaseTools/Source/Python/Common/Misc.py

```diff
-import thread
+try:
+    import thread
+except ImportError:
+    import _thread as thread

-import cPickle
+try:
+    import cPickle
+except ImportError:
+    import pickle as cPickle
```

### BaseTools/Source/Python/Common/String.py

```diff
-import DataType
+from . import DataType

-import EdkLogger as EdkLogger
+from . import EdkLogger as EdkLogger

-import GlobalData
-from BuildToolError import *
+from . import GlobalData
+from .BuildToolError import *
```

**Additional Python files need similar import fixes in**:
- `BaseTools/Source/Python/Common/Parsing.py`
- `BaseTools/Source/Python/UPT/Core/FileHook.py`
- `BaseTools/Source/Python/build/build.py`

### **CRITICAL: Python Syntax Error Fixes**

During the build process, you may encounter Python syntax errors from corrupted imports. These need manual fixing:

#### BaseTools/Source/Python/Common/LongFilePathOs.py
**Error**: `from . from . import LongFilePathOsPath` (duplicate "from .")
**Fix**: Ensure it's `from . import LongFilePathOsPath`

#### BaseTools/Source/Python/Common/String.py  
**Error**: Multiple `from . from . import` statements
**Fix**: Remove duplicates, ensure clean relative imports:
```python
from . import DataType
from . import EdkLogger as EdkLogger  
from . import GlobalData
```

#### BaseTools/Source/Python/Common/Misc.py
**Error**: Corrupted try/except blocks with wrong indentation
**Fix**: Clean up the import section:
```python
try:
    import thread
except ImportError:
    import _thread as thread
try:
    import cPickle
except ImportError:
    import pickle as cPickle
```

---

## 6. XCODE5 Toolchain Compiler Flags

**Purpose**: Suppress strict compiler warnings that cause build failures

**File**: `Conf/tools_def.txt` (generated from `BaseTools/Conf/tools_def.template`)

**Add these flags to XCODE5 X64 compiler lines**:
```
-Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare
```

**Lines to modify**:
- Line 7145: `DEBUG_XCODE5_X64_CC_FLAGS`
- Line 7146: `NOOPT_XCODE5_X64_CC_FLAGS` 
- Line 7147: `RELEASE_XCODE5_X64_CC_FLAGS`

**Note**: The `tools_def.txt` file is regenerated each time you run `source edksetup.sh`, so you may need to re-apply the compiler flag patches if you regenerate the configuration files.

**Example**:
```
RELEASE_XCODE5_X64_CC_FLAGS = -target x86_64-pc-win32-macho -c -Os -Wall -Werror -Wextra -include AutoGen.h -funsigned-char -fno-ms-extensions -fno-stack-protector -fno-builtin -fshort-wchar -mno-implicit-float -mms-bitfields -Wno-unused-parameter -Wno-missing-braces -Wno-missing-field-initializers -Wno-tautological-compare -Wno-sign-compare -Wno-unused-but-set-variable -Wno-varargs -Wno-pointer-compare -ftrap-function=undefined_behavior_has_been_optimized_away_by_clang $(PLATFORM_FLAGS)
```

---

## Build Reproduction Steps

1. **Clone EDK II**:
   ```bash
   git clone https://github.com/tianocore/edk2-archive.git
   cd edk2-archive
   ```

2. **Apply all patches above** (can be done manually or via script)

3. **Set Python 2.7 environment**:
   ```bash
   export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
   ```

4. **Setup EDK II environment**:
   ```bash
   source edksetup.sh
   ```

5. **Build BaseTools**:
   ```bash
   make -C BaseTools
   ```

6. **Build ShellPkg**:
   ```bash
   build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc
   ```

## Build Output

**Success**: `Shell.efi` located at:
- `Build/Shell/RELEASE_XCODE5/X64/Shell.efi` (947 KB)
- File type: PE32+ executable (EFI application) x86-64

## Notes

- These patches are specifically for **legacy EDK II** versions that predate Python 3 support
- Modern EDK II versions may have different requirements
- The XCODE5 toolchain is the recommended choice for macOS builds
- Python 2.7 is **mandatory** for this version of EDK II BaseTools

## Build Variations

### Debug Build
```bash
build -a X64 -t XCODE5 -b DEBUG -p ShellPkg/ShellPkg.dsc
```

### No Optimization Build  
```bash
build -a X64 -t XCODE5 -b NOOPT -p ShellPkg/ShellPkg.dsc
```

### Release Build (Default)
```bash
build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc
```

**All three build targets are fully supported with these patches.**

## Script Creation

For automation, create a patch script that applies all these changes programmatically using `sed`, `awk`, or `patch` commands.
