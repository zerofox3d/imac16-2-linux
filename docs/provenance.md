# Provenance and local layout

Created 9 September 2026 by consolidating the owner's working iMac fixes.

| New location | Original local source |
| --- | --- |
| `audio/` | `~/imac16-2-audio/` |
| `poweroff/` | `~/imac-restart-tests/sleep-intercept/` |
| `poweroff/chipset-read.c` | `~/imac-restart-tests/chipset-read.c` |
| `docs/shutdown-investigation.md` | `~/imac16-2-shutdown-investigation.md` |

The original directories are retained as investigation archives. Installed
configuration and `/usr/src/imac-poweroff-1.0.0` do not depend on either source
folder's location. No active configuration was changed by consolidation.

The original full shutdown logs, compiled experimental modules, EFI/kernel
images and raw ACPI/SMC dumps remain in `~/imac-restart-tests/`. They are not
part of this source project. Relevant verified excerpts are in `validation.md`.
The two successful raw result directories end in `after-20260909T125815Z` and
`after-20260909T130604Z` under the original `sleep-intercept/results/`.

Changes made during consolidation:

- Kept shutdown C source byte-for-byte identical to the tested/installed version.
- Renamed packaging entry points to `poweroff/install.sh` and `uninstall.sh`.
- Replaced the shutdown installer's automatic Omarchy dependency installation
  with explicit generic prerequisite checks. This revised installer has not been
  rerun on the already configured machine.
- Preserved audio executable behaviour and signal-processing values; corrected
  a stale comment saying 300 Hz when the actual crossover is 800 Hz.
- Added a common overview, validation record, upstream work and licence notes.

The audio bundle was developed in an earlier investigation and declared CC0 in
its README. The shutdown work was developed with the owner's observations in
this session; its kernel source declares GPL-2.0. No upstream acceptance or
authorship sign-off is implied by this local project.
