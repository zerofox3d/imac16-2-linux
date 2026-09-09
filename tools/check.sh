#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Source validation only: no install, module load, audio restart or shutdown.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for script in audio/install.sh audio/uninstall.sh audio/tune.sh audio/config/imac-audio-switch; do
  sh -n "$script"
done
for script in poweroff/install.sh poweroff/uninstall.sh poweroff/dkms.conf tools/check.sh; do
  bash -n "$script"
done
build_dir=$(mktemp -d /tmp/imac16-2-check.XXXXXX)
trap 'rm -rf -- "$build_dir"' EXIT
cc -O2 -Wall -Wextra -Werror -o "$build_dir/chipset-read" poweroff/chipset-read.c
cp poweroff/imac_sleep_test.c poweroff/Makefile "$build_dir/"
make -C "$build_dir" -j2
echo 'Shell syntax, read-only probe compilation and kernel module build passed.'
