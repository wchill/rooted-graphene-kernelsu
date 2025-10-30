#!/usr/bin/env bash

set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
python3 "$SCRIPT_DIR"/generate_env.py "$1" "$2" "$3" >> "$4"
