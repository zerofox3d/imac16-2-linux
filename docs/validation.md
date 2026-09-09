# Validation record

## Hardware and scope

One Apple iMac16,2, Retina 4K 21.5-inch Late 2015. Firmware reported in the
investigation: `489.0.0.0.0`; this document does not independently certify that
it is the latest firmware. The original Fusion Drive's SATA disk was replaced
with an SSD. Intel HM97 LPC controller: `8086:8cc3`. CS4208 codec SSID reported
by the audio investigation: `0x106b8100`.

## Audio

The original audio bundle documents kernel `7.1.8-arch1-3`, PipeWire `1.6.8`,
WirePlumber `0.5.15` on Arch/Omarchy. The user confirms the speaker fix works.
Its original README also records headphones, microphone, direct profile
switching and software-volume behaviour. Those audio paths were not retested
while consolidating this project. The crossover was tuned by ear, not calibrated
with measurements. See the [audio investigation](../audio/README.md).

## Power-off

Test kernel: `7.2.3-arch1-3`. Dates/times below are 9 September 2026, BST.

| Test | Observation | Evidence |
| --- | --- | --- |
| macOS installer USB | Successful shutdown on the same hardware | User report |
| Read-only Linux snapshot | `SLP_SMI_EN=1`; TCO halted, no timeout flags | Register probe |
| Module load/unload in observation mode, 13:51 | Register values unchanged | Before/after probe and journal |
| First enabled test, 13:54 | Fans off; remained off for over two minutes; manual power-on | User observation plus EFI pstore readback |
| Second enabled test, 14:00 | Same successful physical result | User observation plus EFI pstore readback |
| Persistent install, 14:09 | DKMS built, installed and loaded; enabling option `Y` | Installer output, module sysfs, source hash |
| Subsequent normal use | User reports success after permanent installation | User report; no new raw shutdown trace collected |

Both enabled trials captured:

```text
imac_sleep_test: after ACPI preparation SMI_EN=00000033 SMI_STS=00004900 PM1_CNT=0001 TCO1_CNT=1800 TCO1_STS=0000 TCO2_STS=0000
imac_sleep_test: clear SLP_SMI_EN: before=00000033 after=00000023 verified=1
reboot: Power down
```

The normal pstore dump occurs before the final power-off callback. It verifies
the earlier clear/readback, not execution of every later instruction. The two
stages were intentionally kept identical between tests and installation.

Tested and installed C source SHA-256:

```text
0b6fbcd816215dab34671c0606c8795dca1476dd6b29aa584cb5464a733183ad
```

## Not yet established

- Reproduction and fixes on a second iMac16,2 or another distribution.
- Whether only one of the two shutdown clearing stages is required.
- Which internal firmware operation fails in the original S5 path.
- Kernel-update operation through an actual future update (DKMS setup verified).
- A complete upstream ALSA fix replacing the audio bundle.
- General support for other CS4208 Macs, different ALSA card ordering or firmware.

Consolidation checks cover shell syntax and compilation, not new hardware trials.
