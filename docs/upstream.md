# Future upstream contributions

The two fixes share a hardware target but belong in separate reports/patches.
Start with the [validation record](validation.md) and include observed behaviour,
exact versions, the smallest reproducer, and the limits of what was tested.

## Omarchy

Propose opt-in, model-specific setup for the two workarounds, with removal paths.
The audio integration needs to run in the desktop user's context; shutdown
installation requires root and DKMS. The shutdown fix is a hardware compatibility
problem, not a regression. The audio situation changed in September 2026: the
`linux-omarchy` kernel's `0512-sound-fixes.patch` adds a CS4208 quirk keyed on
the generic Intel PCI SSID `8086:7270`, which misapplies a MacBook Air pin table
to this iMac and silences the speakers. That is a demonstrated regression and is
filed as [omarchy-pkgs#510](https://github.com/omacom/omarchy-pkgs/issues/510);
the audio bundle now carries `model=mbp11` so it works regardless.

Before submitting, read the current [Omarchy repository](https://github.com/basecamp/omarchy)
instructions and issue/PR templates in a separate source checkout. Use its
suggestions channel for a proposed integration unless filing a validated bug
that fits the current issue policy. No integration has been submitted yet.

## Arch Linux and other distributions

A DKMS source package is a practical distribution route for power-off; audio
could be a separate configuration/tools package. Packaging should install the
same independently reviewable components, respect existing user configuration,
and declare matching headers and audio-stack dependencies. No PKGBUILD, AUR
entry or Debian/RPM package is supplied yet.

The shared installer no longer calls Omarchy to install dependencies. This is
an initial portability improvement, not evidence of a tested cross-distro fix.
For non-systemd distributions, module loading and the audio service need an
equivalent integration.

## Linux kernel and audio projects

For shutdown, present this module as a tested workaround and ask the appropriate
x86/ACPI maintainers about the correct location for a narrow platform quirk.
Keep the DMI/PCI restrictions. Determine whether one clearing stage suffices,
review how firmware interception is intended to work, and test reboot/suspend
before proposing an in-tree change. Do not remove a stage merely for tidiness.

For audio, inspect the current ALSA Cirrus codec implementation and collect
fresh codec information. The old investigation's source path/table is historical.
Separate codec initialisation/channel-map problems from userspace crossover and
profile policy. A kernel quirk has not yet been shown to replace all of the DSP
and routing configuration. Consider the appropriate ALSA/UCM, PipeWire and
WirePlumber contribution paths after narrowing those responsibilities.

Kernel submissions should target the current relevant source tree, use its
`MAINTAINERS`/`scripts/get_maintainer.pl`, and split logically independent fixes.
See the kernel's [patch submission guide](https://docs.kernel.org/process/submitting-patches.html).

## Before wider release

- Obtain results from another matching iMac and record failures as well as success.
- Replace audio card/control-number assumptions with validated discovery.
- Add installer backup/restore support for existing audio customisations.
- Validate tuning inputs and improve switcher failure reporting.
- Exercise DKMS rebuilds and packaging under a second kernel/distribution.
- Preserve component licences and confirm attribution before publication.
- Publish the short evidence excerpt first; review any additional full journals
  separately because they contain unrelated machine/user information.
