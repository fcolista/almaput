#!/bin/sh
#
# upgrade-package.sh - Alpine Linux Multi-Arch Package Upgrade Tool
#
# A POSIX-compliant automation script for Alpine Linux package maintainers.
# Automatically manages Git branches, bumps versions, updates checksums,
# and performs isolated multi-arch builds using abuild rootbld (QEMU/binfmt_misc).
#

set -e

# Auto-detect APORTS directory (Environment variable -> ~/aports -> current dir)
if [ -n "$APORTS_DIR" ]; then
    APORTS_DIR="$APORTS_DIR"
elif [ -d "$HOME/aports" ]; then
    APORTS_DIR="$HOME/aports"
else
    APORTS_DIR="$(pwd)"
fi

# Detect system user for Git branch naming
GIT_USER="${USER:-$(id -un)}"

# Clean environment for abuild rootbld/mktemp isolation
unset TMPDIR
chmod 1777 /tmp 2>/dev/null || true

FORCE=0
if [ "$1" = "-f" ] || [ "$1" = "--force" ]; then
    FORCE=1
    shift
fi

_pkg="$1"
_ver="$2"
ARG3="${3:-edge}"
ARG4="${4:-}"

ALL_KNOWN_ARCHS="x86_64 aarch64 armv7 armhf x86 ppc64le s390x riscv64 all"

is_arch() {
    case " $ALL_KNOWN_ARCHS " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

# Flexible argument parsing
if is_arch "$ARG3"; then
    ALPINE_VER="edge"
    ALPINE_ARCH="$ARG3"
else
    ALPINE_VER="$ARG3"
    ALPINE_ARCH="${ARG4:-x86_64}"
fi

if [ -z "$_pkg" ] \vert{}\vert{} [ -z "$_ver" ]; then
    echo "Alpine Linux Multi-Arch Package Upgrade Tool"
    echo ""
    echo "Usage: $0 [-f|--force] <pkgname> <pkgver> [alpine_ver|arch|all] [alpine_arch|all]"
    echo ""
    echo "Examples:"
    echo "  $0 curl 8.8.0-r0                      # Default: edge branch, x86_64"
    echo "  $0 curl 8.8.0-r0 aarch64               # Target: edge, aarch64"
    echo "  $0 curl 8.8.0-r0 v3.20 aarch64          # Target: v3.20 release, aarch64"
    echo "  $0 curl 8.8.0-r0 edge all             # Target: edge, build all archs"
    echo "  $0 -f curl 8.8.0-r0 all               # Force rebuild on all archs"
    echo ""
    echo "Environment Variables:"
    echo "  APORTS_DIR   Path to your aports repository (Default: $APORTS_DIR)"
    exit 1
fi

echo "# > Cleaning old host build dependencies..."
apk del .makedepends* 2>/dev/null || true

if [ ! -d "$APORTS_DIR/.git" ]; then
    echo "Error: Valid Git repository not found at APORTS_DIR ($APORTS_DIR)"
    exit 1
fi

cd "$APORTS_DIR"
echo "# > Updating git repository ($APORTS_DIR)..."
git checkout master && git pull alpine master 2>/dev/null || git pull origin master

BRANCH_NAME="${GIT_USER}/$_pkg-$_ver"

# Git branch checkout / creation
git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" && \
    git checkout "$BRANCH_NAME" || \
    git checkout -b "$BRANCH_NAME"

PKG_PATH=$(find . -type d -maxdepth 2 -name "$_pkg" | head -n 1)

if [ -z "$PKG_PATH" ]; then
    echo "Error: Package '$_pkg' not found in$APORTS_DIR"
    exit 1
fi

cd "$PKG_PATH"
current_ver=$(. ./APKBUILD; echo "$pkgver")

if [ "$current_ver" = "$_ver" ] && [ "$FORCE" -eq 0 ]; then
    echo "Package $_pkg is already at version$_ver. Use -f or --force to rebuild."
    exit 0
fi

if [ "$FORCE" -eq 1 ] && [ "$current_ver" = "$_ver" ]; then
    echo "# > Force mode enabled: rebuilding $_pkg at version$_ver..."
    abuild checksum
else
    echo "# > Bumping package $_pkg from $current_ver to$_ver..."
    abump "$_pkg-$_ver" && abuild checksum
fi

if [ $? -ne 0 ]; then
    echo "Error: Failed to bump version or update checksums for $_pkg"
    exit 1
fi

if [ "$ALPINE_ARCH" = "all" ]; then
    TARGET_ARCHS="x86_64 aarch64 armv7 armhf x86 ppc64le s390x riscv64"
else
    TARGET_ARCHS="$ALPINE_ARCH"
fi

PASSED_ARCHS=""
FAILED_ARCHS=""

for arch in $TARGET_ARCHS; do
    echo ""
    echo "=========================================================="
    echo "# > Starting rootbld [Arch: $arch \vert{} Branch:$ALPINE_VER]"
    echo "=========================================================="

    unset TMPDIR
    chmod 1777 /tmp 2>/dev/null || true

    if BOOTSTRAP=yes CARCH="$arch" abuild rootbld; then
        echo "# > SUCCESS: Build passed for $_pkg-$_ver on$arch!"
        PASSED_ARCHS="$PASSED_ARCHS$arch"
    else
        echo "# > ERROR: Build failed for $_pkg-$_ver on$arch!"
        FAILED_ARCHS="$FAILED_ARCHS$arch"
    fi
done

# Cleanup temporary makedepends on host
apk del .makedepends* 2>/dev/null || true

# Summary Dashboard
echo ""
echo "=========================================================="
echo "                   BUILD SUMMARY REPORT                   "
echo "=========================================================="
echo "Package : $_pkg-$_ver [$ALPINE_VER]"
echo "Path    : $PKG_PATH"
echo "----------------------------------------------------------"

if [ -n "$PASSED_ARCHS" ]; then
    echo " SUCCESSFUL ARCHS :$PASSED_ARCHS"
fi

if [ -n "$FAILED_ARCHS" ]; then
    echo " FAILED ARCHS     :$FAILED_ARCHS"
fi

echo "=========================================================="

if [ -n "$PASSED_ARCHS" ]; then
    git add .
    git commit -m "${PKG_PATH#./}: upgrade to $_ver" 2>/dev/null || git commit --amend --no-edit 2>/dev/null || true
    
    if [ -n "$FAILED_ARCHS" ]; then
        echo "# > Git commit created, BUT attention: build failed on some architectures!"
        exit 1
    else
        echo "# > All builds & Git commit completed successfully!"
        exit 0
    fi
else
    echo "# > ALL builds failed. Aborting Git commit."
    exit 1
fi
