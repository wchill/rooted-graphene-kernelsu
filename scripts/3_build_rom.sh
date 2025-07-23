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
KSU_VERSION="$(cat "data/${DEVICE}_build_ksu.txt")"
SUSFS_COMMIT="$(cat "data/${DEVICE}_build_susfs.txt")"
export BUILD_DATETIME BUILD_NUMBER GRAPHENE_RELEASE KSU_VERSION SUSFS_COMMIT

### BUILD ROM

echo "=== Starting ROM Build Process ==="
echo "Device: ${DEVICE}"
echo "GrapheneOS Release: ${GRAPHENE_RELEASE}"

# fetch rom sources
echo "Creating and entering ROM directory..."
mkdir -p rom/
pushd rom/ || exit

  echo "Initializing ROM repository ..."
  # sync kernel sources into cache
  if [[ ! -f "${REPO_MIRROR_INSIDE}/rom_is_synced" ]]; then
    mkdir -p "${REPO_MIRROR_INSIDE}/rom" && pushd "${REPO_MIRROR_INSIDE}/rom"
      repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "refs/tags/${GRAPHENE_RELEASE}" --depth=1 --git-lfs   --mirror
      echo "Syncing ROM repository for first time"
      repo_sync_until_success
      touch "${REPO_MIRROR_INSIDE}/rom_is_synced"
    popd || exit
  fi
    
  if [[ ! -f "${REPO_MIRROR_INSIDE}/rom_is_synced" ]]; then
    exit
  fi
  
  echo "Initializing ROM repository into build area..."
  # sync rom sources into repo mirror
  repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "refs/tags/${GRAPHENE_RELEASE}" --depth=1 --git-lfs --reference="${REPO_MIRROR_INSIDE}/rom"
  echo "Syncing ROM repository..."
  repo_sync_until_success

  # copy kernel sources
  echo "Copying kernel build artifacts..."
  # shellcheck disable=SC2010
  KERNEL_DIR=$(ls "device/google/${DEVICE_GROUP}-kernels/${KERNEL_VERSION}" | grep -v '.git')
  rm -rf "device/google/${DEVICE_GROUP}-kernels/${KERNEL_VERSION}/${KERNEL_DIR}/*"
  cp -Rfv ../kernel_out/* "device/google/${DEVICE_GROUP}-kernels/${KERNEL_VERSION}/${KERNEL_DIR}/"
  #rm -rf ../kernel_out # WHY delete??

  echo "Installing adevtool..."
  yarnpkg install --cwd vendor/adevtool/

  echo "Setting up build environment..."
  # shellcheck source=/dev/null
  source build/envsetup.sh

  echo "Building AAPT2..."
  lunch sdk_phone64_x86_64-cur-user
  m arsclib
  m aapt2

  echo "Fetching vendor binaries for ${DEVICE}..."
  ./vendor/adevtool/bin/run generate-all -d "${DEVICE}"

  echo "=== Starting Main ROM Build ==="
  # shellcheck source=/dev/null
  source build/envsetup.sh
  lunch "${DEVICE}-cur-user"
  ${ROM_BUILD_COMMAND}

  echo "=== Generating Keys ==="
  mkdir -p "/dev/shm/graphene-keys/android"
  pushd "/dev/shm/graphene-keys/android" || exit
    echo "Generating signing keys..."
    CN=GrapheneOS
    printf "\n" | /src/rom/development/tools/make_key releasekey "/CN=$CN/" || true
    printf "\n" | /src/rom/development/tools/make_key platform "/CN=$CN/" || true
    printf "\n" | /src/rom/development/tools/make_key shared "/CN=$CN/" || true
    printf "\n" | /src/rom/development/tools/make_key media "/CN=$CN/" || true
    printf "\n" | /src/rom/development/tools/make_key networkstack "/CN=$CN/" || true
    printf "\n" | /src/rom/development/tools/make_key sdk_sandbox "/CN=$CN/" || true
    printf "\n" | /src/rom/development/tools/make_key bluetooth "/CN=$CN/" || true
    echo "Generating AVB key..."
    openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -out avb.pem -passout pass:""
    expect /src/expect/passphrase-prompts.exp /src/rom/external/avb/avbtool.py extract_public_key --key avb.pem --output avb_pkmd.bin
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -f id_ed25519 -N ""

    
  popd || exit
  cp -a "/dev/shm/graphene-keys/android" "/dev/shm/graphene-keys/android-cleartext"

  echo "Encrypting keys..."
  expect ../expect/passphrase-prompts.exp ./script/encrypt-keys "/dev/shm/graphene-keys/android"
  echo "Moving encrypted keys to final destination in ROM build dir"
  mkdir -p "./keys/"
  cp /dev/shm/graphene-keys/android/* "./keys/${DEVICE}/"

  echo "Generating OTA package..."
  m otatools-package

  echo "Finalizing build..."
  expect ../expect/passphrase-prompts.exp script/finalize.sh

  echo "Generating release package..."
  expect ../expect/passphrase-prompts.exp script/generate-release.sh "${DEVICE}" "${BUILD_NUMBER}"
popd || exit

echo "=== Build Complete ==="
echo "Output file location:"
ls "rom/releases/${BUILD_NUMBER}/release-${DEVICE}-${BUILD_NUMBER}/${DEVICE}-ota_update-${BUILD_NUMBER}.zip"

echo "Updating device build record..."
printf "%s\n%s\n%s\n" "${GRAPHENE_RELEASE}" "${KSU_VERSION}" "${SUSFS_COMMIT}" > "data/${DEVICE}_built.txt"

echo "Deleting build markers..."
rm -fv "data/${DEVICE}"_build_*.txt

echo "=== Build Process Finished ==="
