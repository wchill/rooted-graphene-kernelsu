#!/usr/bin/env bash

# Pixel 8 / 8 Pro share the "shusky" device family. The codename "shiba" is the
# GrapheneOS build target for the Pixel 8 specifically.

DEVICE_GROUP="shusky"
DEVICE_REPO="https://github.com/GrapheneOS/device_google_shusky.git"

# Build the kernel from source (Tensor G3, GKI 6.1) with full LTO and without
# downloading Google‑supplied prebuilt GKI images.
# ATTENTION!: The following are removed from Pixel 8 onwards (and maybe earlier as well): --config=no_download_gki --config=no_download_gki_fips140
KERNEL_BUILD_COMMAND="./build_shusky.sh --page_size=16k --lto=full"

# Pre‑built kernel (Image.lz4, modules etc.) from the matching GrapheneOS tag
# – this is only used to extract the stock defconfig so we can spoof ABI checks.
KERNEL_IMAGE_REPO="https://github.com/GrapheneOS/device_google_shusky-kernels_6.1.git"

# Repo manifest that pins the exact kernel sources for all Pixel devices,
# including shusky.  Using the consolidated pixel manifest keeps us aligned
# with upstream GrapheneOS tags.
KERNEL_REPO="https://github.com/GrapheneOS/kernel_manifest-pixel.git"

KERNEL_VERSION="6.1"  # must match the branch in the *_kernels_6.1 repo

# What we actually ask the Android build system to produce for OTA packaging.
ROM_BUILD_COMMAND="m vendorbootimage vendorkernelbootimage target-files-package"

# SUSFS for KernelSU on the Android 14 / 6.1 GKI basis.
SUSFS_BRANCH="gki-android14-6.1"
SUSFS_KERNEL_PATCH="50_add_susfs_in_gki-android14-6.1.patch"

export DEVICE_GROUP \
    DEVICE_REPO \
    KERNEL_BUILD_COMMAND \
    KERNEL_IMAGE_REPO \
    KERNEL_REPO \
    KERNEL_VERSION \
    ROM_BUILD_COMMAND \
    SUSFS_BRANCH \
    SUSFS_KERNEL_PATCH \
    VERSION_CHECK_FILE
