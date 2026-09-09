#!/usr/bin/env bash
# Remove only the locally installed iMac power-off workaround.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.'; exit 1; }
if [[ -d /sys/module/imac_sleep_test ]]; then
  modprobe -r imac_sleep_test
fi
rm -f /etc/modules-load.d/imac-poweroff.conf /etc/modprobe.d/imac-poweroff.conf
if [[ -d /var/lib/dkms/imac-poweroff/1.0.0 ]]; then
  dkms remove imac-poweroff/1.0.0 --all
fi
if [[ -d /usr/src/imac-poweroff-1.0.0 ]]; then
  rm -r /usr/src/imac-poweroff-1.0.0
fi
echo 'Automatic workaround removed and unloaded. Investigation files are retained.'
