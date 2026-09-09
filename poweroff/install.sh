#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[[ $EUID == 0 ]] || { echo 'Root required.'; exit 1; }
[[ $(cat /sys/class/dmi/id/product_name) == iMac16,2 ]] || exit 1
for path in /usr/src/imac-poweroff-1.0.0 /etc/modules-load.d/imac-poweroff.conf /etc/modprobe.d/imac-poweroff.conf /usr/local/sbin/imac-poweroff-remove; do
  [[ ! -e $path ]] || { echo "Already exists; review before replacing: $path"; exit 1; }
done
for module in imac_sleep_test sysoff_eval acpi_eval; do
  [[ ! -d /sys/module/$module ]] || { echo "Conflicting test module loaded: $module"; exit 1; }
done
# Distribution-neutral: install DKMS and matching kernel headers using the
# distribution's package manager before running this installer.
for command in dkms make cc modprobe modinfo install; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command (see README.md)"; exit 1; }
done
[[ -f /lib/modules/$(uname -r)/build/Makefile ]] || {
  echo 'Install the headers for the running kernel first.'; exit 1;
}
install -d -m 755 /usr/src/imac-poweroff-1.0.0
install -m 644 imac_sleep_test.c Makefile dkms.conf /usr/src/imac-poweroff-1.0.0/
dkms add -m imac-poweroff -v 1.0.0
dkms install -m imac-poweroff -v 1.0.0 -k "$(uname -r)"
install -d -m 755 /usr/local/sbin
install -m 755 uninstall.sh /usr/local/sbin/imac-poweroff-remove
install -d -m 755 /etc/modprobe.d /etc/modules-load.d
install -m 644 imac-poweroff.options.conf /etc/modprobe.d/imac-poweroff.conf
modprobe imac_sleep_test
[[ $(cat /sys/module/imac_sleep_test/parameters/clear_sleep_smi) == Y ]]
# Enable future boots only after successfully loading the installed module.
install -m 644 imac-poweroff.modules.conf /etc/modules-load.d/imac-poweroff.conf
dkms status -m imac-poweroff
modinfo -F filename imac_sleep_test
echo 'Loaded for the current boot and configured for future boots.'
echo 'Removal: sudo imac-poweroff-remove'
