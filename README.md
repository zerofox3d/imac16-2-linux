# iMac16,2 Linux fixes

Working audio and reliable shutdown on an Apple **iMac16,2**, Retina 4K
21.5-inch Late 2015, tested on Arch Linux / Omarchy.

This project brings two independently developed fixes together for future
distribution packaging and upstream review. Both are working on the original
machine. Other machines and distributions have not yet been tested.

| Component | Original problem | Working approach |
| --- | --- | --- |
| [Audio](audio/README.md) | Silent internal speakers; incorrect routing and channel mapping | PipeWire crossover, WirePlumber configuration, headphone profile switcher, HDA power-save setting |
| [Power-off](poweroff/README.md) | Screen goes dark, fans keep running, automatic restart after tens of seconds | Model-restricted DKMS module clears Intel `SLP_SMI_EN` during shutdown |

## Contents

```text
audio/       Audio installer, removal/tuning tools and configuration
poweroff/    Tested kernel module, DKMS installer and read-only chipset probe
docs/        Validation evidence, investigation history and upstream work
tools/       Local source/build checks that do not install or activate fixes
```

## Use

Read the component requirements first. Install the components separately:

```sh
# Audio: run as the desktop user. The script requests sudo where needed.
./audio/install.sh

# Power-off: first install DKMS, a compiler/make and matching kernel headers.
sudo bash ./poweroff/install.sh
```

On the original iMac **both fixes are already installed**. Consolidating these
files did not reinstall them; there is no need to run either installer again.
The active shutdown module is deliberately still named `imac_sleep_test` to
preserve the exact code tested twice before permanent installation.

Audio requires PipeWire/WirePlumber and a systemd user session. Power-off uses
DKMS and systemd's modules-load configuration. The power-off installer does not
invoke a distribution-specific package manager. That makes it portable in
principle, but only its Omarchy installation has been exercised so far.

## Evidence and contribution

- [Validated hardware, versions and outcomes](docs/validation.md)
- [Work remaining and proposed upstream routes](docs/upstream.md)
- [Historical shutdown investigation, with corrected conclusions](docs/shutdown-investigation.md)
- [Source provenance and local installation notes](docs/provenance.md)
- [Component licences](LICENSE.md)

Run `./tools/check.sh` for shell syntax and compilation checks. It builds in a
temporary directory and does not load modules, restart audio or shut down.

This project collects the working fixes for testing and future upstream
contributions. No distribution package or upstream patch has been submitted.
Keep audio and shutdown as separate changes when proposing
integration, so maintainers can evaluate each independently.
