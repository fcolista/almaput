# almaput (Alpine Linux Multi-Arch Package Upgrade Tool)

A lightweight, POSIX-compliant shell script designed for **Alpine Linux package maintainers** to automate the process of upgrading aports packages, bumping versions, updating checksums, and building APKs across multiple architectures using isolated `abuild rootbld` containers (via QEMU and `binfmt_misc`).

## Features

- **Automated Git Workflow**: Automatically pulls the latest `master`, creates user-namespaced feature branches (`<username>/<pkg>-<ver>`), updates checksums, and commits changes upon successful builds.
- **Multi-Architecture Execution**: Supports single architecture builds or sequential "one-shot" execution across all Alpine supported architectures (`x86_64`, `aarch64`, `armv7`, `armhf`, `x86`, `ppc64le`, `s390x`, `riscv64`).
- **Build Isolation & Resilience**: Non-blocking multi-arch execution that continues testing all architectures even if one fails, delivering a clean summary report at the end.
- **Flexible Argument Parsing**: Intelligent short-hand syntax (automatically handles 2, 3, or 4 arguments).
- **Force Rebuild Support**: Re-trigger checksum updates and builds even if the package is already at the target version using `-f` or `--force`.

---

## Prerequisites

Ensure your Alpine Linux host system is prepared with QEMU multi-arch emulation and `abuild` build tools:

```sh
# 1. Install required QEMU emulators and build packages
sudo apk add --no-cache \
  qemu-aarch64 qemu-arm qemu-ppc64le qemu-riscv64 qemu-s390x qemu-i386 qemu-x86_64 \
  qemu-img bubblewrap abuild

# 2. Enable binfmt_misc for transparent emulation
sudo modprobe binfmt_misc
sudo rc-update add binfmt default
sudo rc-service binfmt start
```

## Installation
Clone this repository or download the script directly into your executable path:

```
wget [https://raw.githubusercontent.com/YOUR_USERNAME/alpine-upgrade-package/main/upgrade-package.sh](https://raw.githubusercontent.com/YOUR_USERNAME/alpine-upgrade-package/main/upgrade-package.sh)
chmod +x upgrade-package.sh
sudo mv upgrade-package.sh /usr/local/bin/
```

## Configuration
The script automatically attempts to locate your aports repository in the following order:

1. `$APORTS_DIR` environment variable.
2. `$HOME/aports` directory.
3. Current working directory.

If your aports directory is located elsewhere, `export APORTS_DIR` in your shell profile `(~/.profile or ~/.shrc)`:
```
export APORTS_DIR="/path/to/your/aports"
```

## Usage Syntax

```
upgrade-package.sh [-f|--force] <pkgname> <pkgver> [alpine_ver|arch|all] [alpine_arch|all]
```

## Examples
1. Standard Single Architecture Upgrade (Default: x86_64 on edge)
`upgrade-package.sh curl 8.8.0-r0`

2. Target Specific Architecture
`upgrade-package.sh curl 8.8.0-r0 aarch64`

3. Target Specific Alpine Branch & Architecture
`upgrade-package.sh curl 8.8.0-r0 v3.20 aarch64`

4. One-Shot Multi-Arch Build (All Architectures)
```
upgrade-package.sh curl 8.8.0-r0 edge all
# Or using shorthand:
upgrade-package.sh curl 8.8.0-r0 all
```
5. Force Rebuild (Bypass version check)

`upgrade-package.sh -f curl 8.8.0-r0 all`

Sample Output Report
```
==========================================================
                   BUILD SUMMARY REPORT                   
==========================================================
Package : perl-business-isbn-data-20260723.001 [edge]
Path    : ./main/perl-business-isbn-data
----------------------------------------------------------
 SUCCESSFUL ARCHS : x86_64 aarch64 armhf x86 ppc64le s390x
 FAILED ARCHS     : armv7 riscv64
==========================================================
# > Git commit created, BUT attention: build failed on some architectures!
```
