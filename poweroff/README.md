# iMac16,2 power-off workaround

## Result

Normal Linux power-off left fans running and led to an automatic restart after
roughly 30–50 seconds. A macOS installer USB shut down successfully on the same
hardware. Clearing Intel HM97's `SMI_EN.SLP_SMI_EN` during Linux shutdown produced
two consecutive successful tests on 9 September 2026: fans off, no restart for
over two minutes, followed by manual power-on. The user subsequently confirmed
success with the automatically installed workaround.

The persistent installation is DKMS package `imac-poweroff/1.0.0`, module
`imac_sleep_test`, option `clear_sleep_smi=1`. The unusual module name is retained
to keep the proven source identical to the original installation.

## Mechanism and limits

The module checks Apple `iMac16,2`, Intel HM97 PCI ID `8086:8cc3`, and PMBASE
`0x1800`. It clears only bit 4 of `SMI_EN` after ACPI preparation and repeats the
clear immediately before the normal ACPI power-off handler. It does not issue
its own S5 write. Loading/unloading the module does not change chipset registers;
the workaround runs on power-off, not on reboot, halt or suspend.

Intel documents that with `SLP_SMI_EN=1`, a write of `SLP_EN` triggers firmware
SMM handling instead of entering the requested sleep state. The recorded
readback is `SMI_EN: 0x33 -> 0x23`. The bit returned to 1 on subsequent boot.
This strongly implicates the intercepted shutdown path, but does not identify
Apple's internal firmware failure. Which clearing stage is necessary has not
been isolated. See [validation](../docs/validation.md).

Reference: [Intel 9-series datasheet, section 12.8.3.7, printed page 440](https://lab.whitequark.org/files/gpioke/Intel-330550-002.pdf#page=440).

## Install

Requires x86-64 Linux, DKMS, `make`, a C compiler, matching headers for the running
kernel, kmod utilities, and systemd modules-load. Install those prerequisites
using your distribution's package manager. Keep matching headers installed for
future DKMS rebuilds. Enforced module-signature policies need a trusted signing
key; that setup was not tested here.

```sh
sudo bash ./poweroff/install.sh
```

The installer refuses to overwrite an existing installation. It builds the
module, loads it with the enabling option, and only then enables future boot
loading. It does not restart the computer. Normal desktop shutdown can then be
used. Installation is already complete on the original machine.

Installed locations:

- `/usr/src/imac-poweroff-1.0.0/`: DKMS source.
- `/etc/modprobe.d/imac-poweroff.conf`: enabling option.
- `/etc/modules-load.d/imac-poweroff.conf`: boot loading.
- `/usr/local/sbin/imac-poweroff-remove`: removal command.

DKMS rebuilds on kernel updates where the distribution has configured its DKMS
hooks. This was verified for Arch's installed hooks. A future kernel API change
may require updating this external module. It is not an upstream kernel patch.

## Verify or remove

```sh
dkms status -m imac-poweroff
cat /sys/module/imac_sleep_test/parameters/clear_sleep_smi  # expect Y
sudo imac-poweroff-remove
```

The last command removes the workaround; it is not a verification step. It
unloads the module and removes its DKMS source/registration and load settings.
It retains the investigation and DKMS package. The original shutdown problem
may return. The same removal script is supplied as `poweroff/uninstall.sh`.

## Read-only probe

```sh
cc -O2 -Wall -Wextra -Werror -o /tmp/imac-chipset-read poweroff/chipset-read.c
sudo /tmp/imac-chipset-read
```

The probe validates the model's chipset ID and PMBASE, then reads PM1, SMI and
TCO registers without hardware writes. It is diagnostic only, not the fix.
No permanent EFI logging is required for ordinary use.
