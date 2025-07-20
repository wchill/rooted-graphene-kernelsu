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



# Conditional KEY generation

# OTA KEY
pushd "/dev/shm/graphene-keys" || exit
  # load in avbroot passwords
  echo "Loading signing keys..."
  # shellcheck disable=SC1091
  . "passwords.sh"
  mkdir -p signing_keys
  pushd signing_keys || exit
    echo "OTA key..."
    if [ ! -f "ota.key" ]; then
      echo "Generating OTA key..."
      avbroot key generate-key -o ota.key --pass-env-var OTA_PASSWORD --log-level TRACE --log-format long
      if [ ! -f "ota.crt" ]; then
        echo "Generating OTA cert..."
        avbroot key generate-cert -k ota.key -o ota.crt --pass-env-var OTA_PASSWORD --log-level TRACE --log-format long
      fi
    fi
    echo "AVB key..."
    if [ ! -f "avb.pem" ]; then
      echo "Generating AVB key..."
      avbroot key generate-key -o avb.pem --pass-env-var AVB_PASSWORD --log-level TRACE --log-format long
      if [ ! -f "avb_pkmd.bin" ]; then
        avbroot key encode-avb -k avb.pem -o avb_pkmd.bin  --pass-env-var AVB_PASSWORD --log-level TRACE --log-format long
      fi
    fi

    echo "SSH key..."
    if [ ! -f "id_ed25519" ]; then
      echo "Generating SSH key..."
      ssh-keygen -t ed25519 -f id_ed25519 -N ""
    fi
  popd || exit

  
popd || exit
