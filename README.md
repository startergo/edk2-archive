# EDK II ShellPkg Build Guide for macOS

This repository contains the necessary patches and scripts to successfully build the EDK II ShellPkg on macOS, including Apple Silicon (M1/M2/M3) systems.

## Quick Start

### Prerequisites
- **macOS**: Apple Silicon or Intel
- **Xcode Command Line Tools**: `xcode-select --install`
- **Python 2.7**: Required for legacy EDK II build system

### Install Python 2.7 (if not present)
```bash
# Using Homebrew
brew install python@2

# Or download from python.org and install to:
# /Library/Frameworks/Python.framework/Versions/2.7/
```

### One-Command Build
```bash
# Clone and build in one go
git clone https://github.com/startergo/edk2-archive.git
cd edk2-archive
./reset_and_patch.sh  # ✅ Recommended: Works from any state
export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
source edksetup.sh
build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc
```

## Files Included

- **`BUILD_PATCHES_DOCUMENTATION.md`** - Detailed documentation of all patches
- **`reset_and_patch.sh`** ✅ - **Recommended**: Complete reset and patch workflow
- **`apply_build_patches_simple.sh`** - Simple patch application (for clean files)
- **`validate_patches.sh`** - Validation script to verify patches are applied
- **`README.md`** - This file

## Build Process

### Option 1: Complete Reset and Build (Recommended)
```bash
# Works from any state - resets files and applies fresh patches
./reset_and_patch.sh
```

### Option 2: Apply Patches to Clean Files Only
```bash
# Only works if files are in original (unpatched) state
./apply_build_patches_simple.sh
```

### Validate Patches (Optional)
```bash
./validate_patches.sh
```

### Set Environment and Build
```bash
export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
source edksetup.sh
build -a X64 -t XCODE5 -b RELEASE -p ShellPkg/ShellPkg.dsc
```

## Workflow Scripts Explained

### `reset_and_patch.sh` ✅ **Recommended**
- **Use When**: Any time you want a clean build
- **What It Does**: 
  - Resets all files to original state using `git checkout`
  - Cleans build artifacts (`rm -rf Build/` and `Conf/.cache`)
  - Applies fresh patches automatically
- **Advantage**: Works regardless of current file state (patched/unpatched/corrupted)

### `apply_build_patches_simple.sh`
- **Use When**: First-time setup with clean (original) files
- **What It Does**: Applies only essential patches without complex Python fixes
- **Limitation**: Won't work if files are already patched

### Why Multiple Scripts?
Once files are patched, applying patches again can fail. The reset script solves this by restoring originals first, ensuring reliable builds every time.

## Build Output

**Success Location**: `Build/Shell/RELEASE_XCODE5/X64/Shell.efi`

**File Details**:
- **Size**: ~947 KB
- **Type**: PE32+ executable (EFI application) x86-64
- **Usage**: UEFI Shell application for x64 systems

## What the Patches Fix

### 1. **Apple Silicon Compatibility**
- Maps macOS `arm64` architecture to EDK II `AARCH64` 
- Enables BaseTools compilation on Apple Silicon Macs

### 2. **Compiler Compatibility** 
- Fixes macro redefinitions (`UINT8_MAX`)
- Corrects bitwise alignment operations
- Resolves pointer comparison warnings

### 3. **Python 2/3 Compatibility**
- Updates relative imports for Python 3 compatibility
- Maintains Python 2.7 fallback support
- Fixes octal literal syntax
- **Handles Python syntax corruption** from manual edits

### 4. **XCODE5 Toolchain**
- Suppresses strict compiler warnings for **all build types**:
  - `-Wno-unused-but-set-variable`
  - `-Wno-varargs` 
  - `-Wno-pointer-compare`
- **Supports DEBUG, RELEASE, and NOOPT builds**

## Troubleshooting

### Build Fails with "command not found: build"
```bash
# Ensure EDK II environment is sourced
source edksetup.sh
```

### Python Import Errors
```bash
# Ensure Python 2.7 is in PATH
export PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:$PATH"
python --version  # Should show 2.7.x
```

### Compiler Warnings as Errors
```bash
# Re-run patch script to update compiler flags
./apply_build_patches.sh
```

### "No rule to make target" Errors
```bash
# Rebuild BaseTools
make -C BaseTools clean
make -C BaseTools
```

## Manual Patch Application

If the automated script fails, see `BUILD_PATCHES_DOCUMENTATION.md` for detailed manual patch instructions.

## Original vs Patched Code

All changes maintain compatibility with the original EDK II codebase while enabling successful builds on modern macOS systems. The patches are minimal and surgical, targeting only specific compatibility issues.

## Build Variations

### Debug Build
```bash
build -a X64 -t XCODE5 -b DEBUG -p ShellPkg/ShellPkg.dsc
```

### No Optimization Build  
```bash
build -a X64 -t XCODE5 -b NOOPT -p ShellPkg/ShellPkg.dsc
```

## Testing the Built Shell

The resulting `Shell.efi` can be used in any UEFI environment:

1. **QEMU**: Add to EFI system partition
2. **Physical Hardware**: Copy to EFI/BOOT/ directory  
3. **VMware/VirtualBox**: Mount as UEFI application

## Contributing

If you encounter additional build issues or have improvements:

1. Document the problem and solution
2. Update the patch scripts accordingly
3. Test on both Intel and Apple Silicon Macs
4. Submit a pull request with detailed explanation

## Version Compatibility

These patches are tested with:
- **EDK II**: Legacy archive versions (pre-Python 3 support)
- **macOS**: 12.0+ (Monterey and later)
- **Xcode**: 13.0+ command line tools
- **Python**: 2.7.x (legacy requirement)

For modern EDK II versions with Python 3 support, some patches may not be necessary.

## License

This build guide and patches follow the same license as the original EDK II project (BSD-2-Clause-Patent).
