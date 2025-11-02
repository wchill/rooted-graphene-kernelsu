#!/usr/bin/env bash

set -e

ORIGINAL_OTA=$(realpath "$1")
BOOT_IMG=$(realpath "$2")
AVB_KEY=$(realpath "$3")
ORIG_EXTRACT=$(pwd)/extracted_original
AVBROOT=$(pwd)/avbroot
OLD_PWD=$(pwd)

$AVBROOT ota extract -i "$ORIGINAL_OTA" -d "$ORIG_EXTRACT"

mkdir -p extract_tmp
pushd extract_tmp/ || exit
  mkdir -p original
  pushd original/ || exit
    $AVBROOT avb unpack -i "$ORIG_EXTRACT"/boot.img
    $AVBROOT boot unpack -i raw.img
  popd || exit

  if [[ $BOOT_IMG != *"Image.lz4" ]]; then
    mkdir -p new
    pushd new/ || exit
      $AVBROOT boot unpack -i "$BOOT_IMG"
      cp kernel.img ../original/kernel.img
    popd || exit
  else
    cp $BOOT_IMG original/kernel.img
  fi

  pushd original/ || exit
    $AVBROOT boot pack -o raw.img
    $AVBROOT avb pack -o "$OLD_PWD"/boot.modified.img -k "$AVB_KEY"
  popd || exit
popd || exit
