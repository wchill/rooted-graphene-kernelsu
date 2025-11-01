#!/usr/bin/env bash

ORIGINAL_OTA="$1"
BOOT_IMG="$2"
AVB_KEY="$3"
ORIG_EXTRACT=$(pwd)/extracted_original
AVBROOT=$(pwd)/avbroot

$AVBROOT ota extract -i "$ORIGINAL_OTA" -d "$ORIG_EXTRACT"

mkdir -p extract_tmp
pushd extract_tmp/ || exit
  mkdir -p original
  pushd original/ || exit
    $AVBROOT avb unpack -i "$ORIG_EXTRACT"/boot.img
    $AVBROOT boot unpack -i raw.img
  popd || exit

  mkdir -p new
  pushd new/ || exit
    $AVBROOT boot unpack -i "$BOOT_IMG"
  popd || exit

  cp new/kernel.img original/kernel.img

  pushd original/ || exit
    $AVBROOT boot pack -o raw.img
    $AVBROOT avb pack -o "$ORIG_EXTRACT"/boot.img -k "$AVB_KEY"
  popd || exit
popd || exit