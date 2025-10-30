#!/usr/bin/env bash

# exit on error
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# include device-specific variables
DEVICE_ID="${1,,}"

echo "Checking if release needed..."
python3 "$SCRIPT_DIR"/check_if_release_necessary.py "$BUILD_METADATA_FILE" && error_code=0 || error_code=$?
case $error_code in
    0) ;;
    2) echo "Release already exists; release not needed."; exit 0;;
    *) echo "Error when checking release (exit code ${error_code}), assuming release required. Continuing.";;
esac

### BUILD KERNEL

echo "=== Starting Kernel Build Process ==="
echo "Device: ${DEVICE_ID}"
echo "GrapheneOS Release: ${GRAPHENEOS_VERSION}"

# fetch kernel sources
echo "Creating and entering kernel directory..."
if [[ "$DEVICE_ID" == "dummy" ]]; then
  echo "Dummy build, skipping initialization..."
  mkdir -p kernel/
elif [ -d "kernel" ]; then
  echo "Kernel directory already exists. Skipping initialization..."
else
  eval "${KERNEL_FETCH_COMMAND}"
  pushd kernel/ || exit

    # remove abi_gki_protected_exports files
    echo "Removing ABI GKI Protected Exports..."
    rm -fv "common/android/abi_gki_protected_exports_*"

    mkdir -p aosp
    # fetch & apply ksu and susfs patches
    pushd aosp/ || exit
      if [[ -v KERNEL_IMAGE_REPO ]]; then
        echo "Fetching stock defconfig from ${KERNEL_IMAGE_REPO}..."
        git clone --depth=1 --branch "${GRAPHENEOS_VERSION}" --single-branch "${KERNEL_IMAGE_REPO}" kernel_image/
        echo "Extracting kernel image configuration..."
        lz4 -d kernel_image/grapheneos/Image.lz4 kernel_image/Image
        ./scripts/extract-ikconfig kernel_image/Image > arch/arm64/configs/stock_defconfig
        rm -rf kernel_image/
      else
        echo "KERNEL_IMAGE_REPO not set, skipping fetching defconfig."
      fi

      # apply kernelsu
      echo "Setting up KernelSU..."
      curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s "${KERNELSU_BRANCH}"

      # hardcode kernelsu version
      pushd KernelSU-Next/ || exit
        echo "Configuring KernelSU version..."
        KERNELSU_VERSION=$(($(git rev-list --count HEAD) + 10200))
        echo "Using KernelSU version: ${KERNELSU_VERSION}"
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
    if [[ -v KERNEL_IMAGE_REPO ]]; then
      patch -p1 < "../patches/0003-spoof-stock-defconfig.patch"
    else
      echo "KERNEL_IMAGE_REPO not set, skipping stock defconfig spoof patch."
    fi

    echo "6. Applying 'clean kernel version' patch..."
    patch -p1 < "../patches/0004-clean-kernel-version.patch"

    #  echo "7. Applying 'Disable KMI symbol strict‑mode for the 16 KiB GKI build' patch..."
    #  patch -p1 < "../patches/0005-disable-KMI-symbol-strict-mode-for-the-16-KiB-GKI-build.patch"
  popd || exit
fi

pushd kernel/ || exit
  echo "=== Building Kernel ==="
  # build kernel
  eval "${KERNEL_BUILD_COMMAND}"
popd || exit

echo "=== Moving Build Artifacts ==="
# stash parts we need
mv -v "kernel/out/${DEVICE_GROUP}/dist" "./kernel_out"

# TODO: Can we get away with just the boot.img?

echo "=== Zipping artifacts ==="
pushd kernel_out/ || exit
  mkdir -p ../build_output/
  zip -r ../build_output/kernel-"${DEVICE_ID}"-"${GRAPHENEOS_VERSION}".zip .
popd || exit

echo "=== Kernel Build Complete ==="
