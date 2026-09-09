# iMac16,2 — Linux fails to power off: investigation summary

> **Update, 9 September 2026:** The user confirms that a macOS installer USB
> successfully shut this machine down with its current hardware. Previous Linux
> tests have not succeeded. The historical conclusions below that macOS is
> untested and an OS-side solution is impossible are superseded. A read-only
> HM97 register check found `SLP_SMI_EN=1`; the TCO watchdog is halted, with no
> timeout flags. A targeted, temporary sleep-interception test is documented in
> [poweroff/README.md](../poweroff/README.md).
> **First test succeeded at 13:54 BST:** fans stopped, the machine remained off
> for over two minutes, and the user powered it on manually. EFI pstore confirms
> `SMI_EN` changed from `0x33` to `0x23` after ACPI preparation
> (`SLP_SMI_EN` cleared, readback verified). After boot it is back to `0x33`
> and the temporary module is absent at that point.
> **Second trial at 14:00 BST also succeeded**, with the same verified register
> change and user-observed sustained power-off.
> **Automatic workaround installed at 14:09 BST:** DKMS package
> `imac-poweroff/1.0.0`, using the exact tested `imac_sleep_test` source.
> It is loaded with `clear_sleep_smi=1` now and configured to load on boot.
> DKMS will rebuild it on kernel updates (matching headers required).
> Remove with `sudo imac-poweroff-remove`. No permanent diagnostic pstore
> logging is enabled. Full installation details are in the linked README.

**Current status (9 September):** Two successful Linux power-offs using the
SLP_SMI_EN workaround; automatic loading and DKMS integration installed.
macOS installer shutdown also succeeds. SMC-only attribution is superseded.
The sections below preserve the earlier investigation; see the update above.
**Date:** 28 August 2026
**Machine:** Apple iMac16,2 (Retina 4K 21.5-inch, Late 2015), firmware `489.0.0.0.0` (latest available)
**OS:** Omarchy 4.0.0 (Arch Linux), kernel 7.1.8-arch1-3

---

## 1. The symptom

`systemctl poweroff` never leaves the machine off:

1. Shutdown proceeds normally; all filesystems, swaps, loop/MD/DM devices detach cleanly.
2. Display goes dark, USB power drops.
3. **Fans keep running** — the board is still powered, CPU halted.
4. After ~50 seconds the machine restarts: Apple chime, full cold boot with RAM training.

A **brief** power-button press during the dead period does nothing (in a true S5 it would power
the machine on); press-and-hold stops the fans; a further press boots normally.

Reboot (`systemctl reboot`) works correctly, every time.

---

## 2. What is established

### 2.1 The kernel completes the entire shutdown path

Captured from the kernel ring buffer via `efi-pstore` + `printk.always_kmsg_dump=1`, written to
EFI NVRAM at `kmsg_dump(KMSG_DUMP_SHUTDOWN)` — the call immediately before `machine_power_off()`.
This survives the cold reset, unlike the console.

```
shutdown[1]: Powering off.
sd 0:0:0:0: [sda] Synchronizing SCSI cache
sd 0:0:0:0: [sda] Stopping disk
ACPI: PM: Preparing to enter system sleep state S5
kvm: exiting hardware virtualization
reboot: Power down                      <- reached on every poweroff
fbcon: Taking over console
```

A control run (`reboot`) produced the same record ending `reboot: Restarting system`.

**Conclusion:** the kernel reaches the final instruction before the S5 register write, every time.

### 2.2 The console was misleading — this cost two days

Earlier screen captures appeared to show the hang wandering between runs (mid-`_PTS`,
at `kvm:`, at `Power down`). This is an artefact: DRM fbcon renders through
`drm_fb_helper_damage_work`, a scheduled worker, so console text lags printk and freezes when
workers stop. **Four wrong root causes were derived from trusting the last line on screen.**
The pstore method above is the reliable instrument.

### 2.3 Reboot runs the same ACPI preparation as poweroff

`drivers/acpi/sleep.c:1132` registers `acpi_power_off_prepare` for `SYS_OFF_MODE_RESTART_PREPARE`
as well ("Windows uses S5 for reboot, so some BIOSes depend on it"). The reboot control record
contains `ACPI: PM: Preparing to enter system sleep state S5`.

**Conclusion:** `_PTS(5)`, GPE disable, event flush and `syscore_shutdown()` are all exonerated —
reboot performs them and works.

### 2.4 Linux already identifies as macOS to the firmware

Every boot:

```
ACPI: DMI detected to setup _OSI("Darwin"): Apple hardware
ACPI: Disabled all _OSI OS vendors
ACPI: BIOS _OSI(Darwin) query honored via DMI
```

(`drivers/acpi/osi.c:483`, `if (x86_apple_machine)`.) So `OSYS = 0x2710`, `OSDW()` returns 1
always, and every `If (!OSDW())` branch in the firmware tables is **dead code** on this machine.

**Consequence:** the "firmware treats Linux differently" theory is void; `acpi_osi=Darwin` is a
no-op here; a DSDT override deleting code in those branches removes code that never executed.

### 2.5 The SMC performs a genuine power-off and restarts anyway

The SMC's "Ninja Action Timer" (`NATJ=1` = *Force Shutdown to S5*, `NATi` = seconds) was armed
directly over the SMC port interface. It fired twice — once against a hung shutdown, once against
a **normally running system with no OS shutdown involved at all**. Both times the machine powered
down and then **powered itself back on**.

Afterwards the SMC recorded `MSSD = 0xC3` (-61, `STOP_CAUSE_NINJA_SHUTDOWN`).

**This is the decisive result.** The power-off itself works. The automatic restart afterwards is
SMC policy, independent of the operating system, and no kernel-side change could ever have
prevented it.

### 2.6 The SMC classifies every Linux shutdown as -63

`MSSD` reads `0xC1` (-63) after every ordinary chime-restart. The code is undocumented in both
Apple's key reference and the community table. Under macOS, `-63` appears in reports of Macs
"restarting without any reason" ([Apple Community 250588718](https://discussions.apple.com/thread/250588718)).

Writing `MSSD = 5` ("clean shutdown") before power-off does not help — the SMC overwrites it with
its own classification. The cause code is awarded by the SMC, not set by the OS.

---

## 3. Avenues investigated

### 3.1 Wake sources — all negative

The first eleven tests assumed the machine powered off and something woke it. It does not power
off, so all were aimed at an event that never occurs.

- All ACPI wake sources (`/proc/acpi/wakeup`), all PCI PME (`power/wakeup`), all USB wakeup
- Apple keyboard physically unplugged
- Both radios via `rfkill block all`
- `applesmc` and `thunderbolt` modules unloaded
- Full PRAM/NVRAM reset; SMC reset
- RTC wakealarm (verified disabled: `alarm_IRQ: no`)
- Restart-after-power-failure (re-plugging mains does not start the machine)
- Ethernet Wake-on-LAN disabled in the chip (`ethtool -s eno1 wol d`, verified `Wake-on: d`).
  The chip reports `Supports Wake-on: g` — MagicPacket only — and no cable is attached.

### 3.2 Shutdown mechanism — all negative

- `systemctl poweroff -ff` (raw `reboot()` syscall, bypasses systemd entirely)
- EFI `ResetSystem(EfiResetShutdown)` via a custom `sys_off` handler
- `systemctl halt` (sits quietly; no restart, but no power-off either)

### 3.3 Devices and drivers — all negative

- `brcmfmac` unloaded **and** BCM43602 removed from the PCI bus
- Orphaned Apple S1X NVMe blade removed from the PCI bus
- `kvm` / `kvm_intel` unloaded — and the `kvm:` line appears in a run that got *further*,
  so it had already completed
- Intel ME stack (`mei`, `mei_me`, `mei_hdcp`, `mei_pxp`) unloaded
- `acpi_mask_gpe=0x17` (EC GPE), verified effective — event count 0

### 3.4 CPU idle / cross-CPU — negative

- `idle=poll` (cores never enter C6; deep-idle IPI-response theory)
- `maxcpus=1` (collapses every cross-CPU IPI in the shutdown path)

Precedent existed for both — the kernel has patched `stop_other_cpus()` twice for shutdown hangs
([2019 NMI fallback](https://lkml.iu.edu/hypermail/linux/kernel/1909.2/06491.html),
[2023 Gleixner series](https://lkml.rescloud.iu.edu/2306.1/08778.html)) and a
[MacBook shutdown hang was fixed by `intel_idle.max_cstate=1`](https://forums.linuxmint.com/viewtopic.php?t=356252) —
but neither applies here.

### 3.5 Firmware ACPI tables — all negative

All tables decompiled with `iasl` and searched.

- **DSDT override**: patched `_PTS`, recompiled (0 errors), loaded via the mkinitcpio
  `acpi_override` hook, confirmed live in the kernel log by a bumped OEM revision
  (`0x00410001` → `0xF0000001`). No change. (Later shown to have edited dead code — see §2.4.)
- **Apple device power-cut methods**, evaluated via a purpose-built module both before poweroff
  and from inside the power-off path at the S5 doorstep:
  - `\_SB.PCI0.PEG0._PS3` — NVMe blade power rail (`GP15 = 0`)
  - `\_SB.PCI0.SATA.PRT0._PS3` — SATA port power (`GP08 = 0`)
  - `\_SB.PCI0.PEG1.UPSB.DSB0.NHI0.SXFP(0)` — Thunderbolt force-power (`GP23 = 0`)
- No `_GTS`/`_BFS` legacy sleep hooks exist. No `PowerResource` objects exist.
- The `TRAP` SMI method has no callers; the Thunderbolt mailbox (`TBTC`) is only invoked from
  `If (!OSDW)` branches — dead code (§2.4).
- FADT register addressing is internally consistent (`PM1a_CNT` 0x1804, `PM1a_EVT` 0x1800,
  `GPE0` 0x1820), so `acpi_force_32bit_fadt_addr` is inapplicable.
- PM1 registers at rest are healthy: `SCI_EN=1`, no stuck status bits, `WAK_STS` clear.

### 3.6 SMC keys — all negative

626 keys enumerated. Written both from userspace and, for `AUPO`, from **inside the kernel's
power-off path** via raw port I/O (0x300/0x304), so nothing could re-arm it afterwards.

| Key | Meaning | Result |
|---|---|---|
| `AUPO` | *"Auto Power-on key. If set to 1, system will be automatically powered on by SMC after next transition to S5/G3HOT."* (Apple's own key reference) | Already 0; explicitly cleared; no change |
| `AUWT` | Undocumented, the only non-zero policy value (450) | Cleared; no change |
| `MSSD` | Shutdown cause | Set to 5 ("good"); SMC overwrote with -63 |
| `NTOK` | *"Interrupt OK — write one to enable host notifications"* | Written; no change |
| `MSDW` | OS notifies SMC display awake/asleep | Written; no change |
| `NATJ`/`NATi` | Ninja Action Timer, force S5 | **Powers off, then auto-restarts** (§2.5) |

Zero on this machine and therefore not implicated: `G3AO`, `G3WD`, `NOPB`, `ONMI`, `URWD`,
`DSAS`, `WKEN`, `WKTP`, `OSWD`.

### 3.7 Firmware update

`489.0.0.0.0` confirmed as the latest available for this model.

---

## 4. Conclusion

The fault is **not in the operating system**. The kernel reaches the final pre-S5 instruction on
every attempt, and the SMC's *own* forced power-off — invoked with no OS involvement — also ends
in an automatic restart. The behaviour lives in SMC firmware, which exposes no further interface
that Linux can reach.

Every OS-visible lever has been exhausted: the kernel shutdown path, ACPI/AML including a live
patched DSDT, the firmware's device power-cut methods, and the SMC's documented power-state,
auto-power-on, watchdog and notification keys.

**Open question:** whether this SMC still shuts down correctly under macOS. The assumption that it
did is from before the Fusion Drive was replaced with a SATA SSD, i.e. before the machine was
opened. If macOS also auto-restarts, this is a hardware fault (consistent with -63 appearing in
macOS reports of spontaneous restarts) rather than a Linux problem. **This test has not been run**
and is the only remaining step that would change the diagnosis. Route without a second Mac:
Internet Recovery (Cmd+R at boot), then shut down from the Apple menu.

**Prior art:** the same symptom on the same model has been
[reported and unresolved since 2021](https://bbs.archlinux.org/viewtopic.php?id=272165)
(kernels 5.4–5.15), and reproduced across Fedora, Ubuntu, elementary, Arch, Manjaro and Pop!_OS
on kernels 5.4–5.17. It is not distribution-specific and predates this installation by five years.

**Workaround:** hold the power button (~5 seconds).

---

## 5. Method notes (reusable)

- **Capture the kernel's true position at shutdown** — the console cannot be trusted (§2.2):
  `modprobe ec_sys`-style runtime arming of `efi-pstore` (`printk.always_kmsg_dump=1`,
  `efi_pstore.pstore_disable=0`), then read `/sys/fs/pstore` on the next boot. Records survive the
  cold reset in EFI NVRAM. Note `efi_pstore` re-disables itself every boot.
- **ACPI method tracing** (`CONFIG_ACPI_DEBUG=y`):
  `printf '%s' '\_PTS' > /sys/module/acpi/parameters/trace_method_name` then
  `printf '%s' 'opcode-once' > .../trace_state`. **Use `printf`, not `echo`** —
  `param_set_trace_method_name()` `strcpy`s the raw sysfs buffer, so a trailing newline makes the
  name never match and the trace produces nothing, silently.
- **Name the syscore callbacks:** `initcall_debug` makes `syscore_shutdown()` print
  `PM: Calling %pS` before each one.
- **`nomodeset`** gives a `simpledrm` console that survives device teardown further than `i915`.
- **Read/write SMC keys from Linux:** protocol in `drivers/hwmon/applesmc.c`
  (ports 0x300 data / 0x304 command); unload `applesmc` first. Key reference:
  [VirtualSMC `Docs/SMCKeys.txt`](https://github.com/acidanthera/VirtualSMC/blob/master/Docs/SMCKeys.txt)
  and `Docs/SMCKeysMacPro.html` (Apple's own legacy descriptions).

Working files, scripts and decompiled tables: `~/imac-restart-tests/`.
