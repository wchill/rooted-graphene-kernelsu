#!/usr/bin/env bash

# exit on error
set -e

# include common functions
# shellcheck disable=SC1091
. "scripts/0_includes.sh"

# include device-specific variables
DEVICE="${1,,}"
# shellcheck disable=SC1090
. "devices/${DEVICE}.sh"

# import build markers
BUILD_DATETIME="$(cat "data/${DEVICE}_build_datetime.txt")"
BUILD_NUMBER="$(cat "data/${DEVICE}_build_number.txt")"
GRAPHENE_RELEASE="$(cat "data/${DEVICE}_build_graphene.txt")"
export BUILD_DATETIME BUILD_NUMBER

### BUILD KERNEL

echo "=== Starting Kernel Build Process ==="
echo "Device: ${DEVICE}"
echo "GrapheneOS Release: ${GRAPHENE_RELEASE}"

# fetch kernel sources
echo "Creating and entering kernel directory..."
if [ ! -d "kernel" ]; then
  git clone https://gitlab.com/grapheneos/kernel_pixel.git -b "refs/tags/${GRAPHENE_RELEASE}" --recurse-submodules kernel
  pushd kernel/ || exit

    # remove abi_gki_protected_exports files
    echo "Removing ABI GKI Protected Exports..."
    rm -fv "common/android/abi_gki_protected_exports_*"

    mkdir -p aosp
    # fetch & apply ksu and susfs patches
    pushd aosp/ || exit
      echo "Fetching stock defconfig from ${KERNEL_IMAGE_REPO}..."
      git clone --depth=1 --branch "${GRAPHENE_RELEASE}" --single-branch "${KERNEL_IMAGE_REPO}" kernel_image/
      echo "Extracting kernel image configuration..."
      lz4 -d kernel_image/grapheneos/Image.lz4 kernel_image/Image
      ./scripts/extract-ikconfig kernel_image/Image > arch/arm64/configs/stock_defconfig
      rm -rf kernel_image/

      # apply kernelsu
      echo "Setting up KernelSU..."
      curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s ${KERNELSU_NEXT_BRANCH}

      # hardcode kernelsu version
      pushd KernelSU-Next/ || exit
        echo "Configuring KernelSU version..."
        KSU_VERSION=$(($(git rev-list --count HEAD) + 10200))
        echo "Using KernelSU version: ${KSU_VERSION}"
        sed -i '/^ccflags-y += -DKSU_GIT_VERSION=/d' kernel/Makefile
        sed -i '1s/^/ccflags-y += -DKSU_GIT_VERSION='"${KSU_VERSION}"'\n/' kernel/Makefile
      popd || exit

      echo "Fetching SUSFS from branch ${SUSFS_BRANCH}..."
      git clone --depth=1 "https://gitlab.com/simonpunk/susfs4ksu.git" -b "${SUSFS_BRANCH}"

      # apply patches
      echo "=== Applying Patches ==="
      pushd KernelSU-Next/ || exit
      #   echo "1. Applying SUSFS to KernelSU..."
      #   patch -p1 < "../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"
      #
        echo "2. Applying 'additional signatures' patch..."
        patch -p1 < "../../../patches/0001-add-managed-sigs.patch"
      popd || exit

      echo "3. Applying SUSFS kernel patches..."
      patch -p1 < "susfs4ksu/kernel_patches/${SUSFS_KERNEL_PATCH}"

      echo "3. Copying SUSFS files to kernel..."
      cp -v susfs4ksu/kernel_patches/fs/*.c fs/
      cp -v susfs4ksu/kernel_patches/include/linux/*.h include/linux/
    popd || exit

    echo "4. Applying 'wireguard by default' patch..."
    patch -p1 < "../patches/0002-enable-wireguard-by-default.patch"

    echo "5. Applying 'stock defconfig spoof' patch..."
    patch -p1 < "../patches/0003-spoof-stock-defconfig.patch"

    echo "6. Applying 'clean kernel version' patch..."
    patch -p1 < "../patches/0004-clean-kernel-version.patch"

    #  echo "7. Applying 'Disable KMI symbol strict‑mode for the 16 KiB GKI build' patch..."
    #  patch -p1 < "../patches/0005-disable-KMI-symbol-strict-mode-for-the-16-KiB-GKI-build.patch"
  popd || exit
fi

pushd kernel/ || exit
  echo "=== Building Kernel ==="
  # build kernel
  ${KERNEL_BUILD_COMMAND}
popd || exit

echo "=== Moving Build Artifacts ==="
# stash parts we need
mv -v "kernel/out/${DEVICE_GROUP}/dist" "./kernel_out"

echo "=== Cleaning Up ==="
# remove kernel sources to save space before rom clone: SKIP FOR NOW
#rm -rf kernel/

echo "=== Kernel Build Complete ==="
