# iMac16,2 built-in audio on Linux

Part of [iMac16,2 Linux fixes](../README.md). The diagnosis below records the
original August 2026 investigation, not a fresh audit of current upstream ALSA.
The supplied audio configuration and signal-processing values are preserved.

### Requirements and portability

Run the installer as the desktop user, **not through `sudo`**; it requests sudo
for the system configuration itself. Requires PipeWire with filter-chain support,
WirePlumber 0.5-style configuration, pipewire-pulse (`pactl` client), ALSA tools
(`amixer`, `alsactl`), and a systemd user session. The installer restarts audio
and overwrites its named configuration files; preserve any existing customisations
before reinstalling. Uninstall removes those files rather than restoring backups.

The switcher assumes ALSA card 1 and PCI address `00:1b.0`; it addresses ALSA
controls by name, because a kernel update renumbered them.
Those assumptions are verified only on the original machine. Other card ordering
or profiles need validation before use. The tuning script expects three numeric
arguments; defaults are 800 Hz, woofer gain 2.0 and tweeter gain 0.5.

See [validation](../docs/validation.md) and [upstream work](../docs/upstream.md).

Working built-in speakers, headphones and microphone on an **Apple iMac16,2**
(21.5-inch, Late 2015) running Arch Linux / Omarchy with PipeWire.

Out of the box the internal speakers are completely silent and PipeWire defaults
to a dead HDMI output. This is not a PipeWire misconfiguration — the kernel has
no quirk for this machine's codec.

## Why it fails

The codec is a Cirrus Logic **CS4208** (`00:1b.0`, SSID `0x106b8100`). The kernel's
`cs4208_mac_fixups[]` table in `sound/pci/hda/patch_cirrus.c` only covers
`5e00` (MBP11,2), `6c00` (MacMini7,1), `7100`/`7200` (MBA6,x) and `7b00` (MBP12,1).
`0x8100` is absent, so the driver falls back to the generic `CS4208_GPIO0` path.
You can see this in `dmesg`:

    snd_hda_codec_cs420x hdaudioC1D0: CS4208: picked fixup  for codec SSID 106b:0000
                                                          ^^ blank = no quirk matched

That leaves six separate problems:

| # | Problem | Fix |
|---|---------|-----|
| 1 | PipeWire defaults to the Intel display-audio output, which reports `monitor_present 0` / `eld_valid 0` — it can never produce sound | point the default sink at the analog card |
| 2 | `power_save=10` suspends the codec; its resume path never re-enables the speaker amplifier, so audio works for ~30 min after boot then dies permanently | `options snd_hda_intel power_save=0` |
| 2b | The Omarchy kernel applies a MacBook Air pin table to this iMac via an over-broad quirk (see below) | `options snd_hda_intel model=mbp11,mbp11` |
| 3 | Plain 2-channel playback is silent — the speakers only sound from the 4-channel PCM | use the `analog-surround-40` profile |
| 4 | The driver advertises the 4-channel map as `FL,FR,LFE,LFE`, which is wrong. The real wiring is `slots 0,1 = LEFT` and `slots 2,3 = RIGHT` | `api.alsa.use-chmap = false` + explicit `audio.position` |
| 5 | Each speaker is bi-amped with no passive crossover, so every driver receives full-range audio and it sounds thin | software crossover (PipeWire filter-chain) |
| 6 | Headphones only work on the `analog-stereo` profile — the analog output produces nothing while the card runs the 4-channel stream | jack-driven profile switcher |

Plus one that only shows up later: the codec's `Master Playback Volume` is an
**analog** amp control, and the speakers are on the codec's *digital* pins, which
have no amp. So the volume slider does nothing for the speakers until you set
`api.alsa.soft-mixer = true` (a **device** property; setting it on the node is
silently ignored).

### The Omarchy kernel breaks this (and how the fix covers it)

`linux-omarchy` (first seen in 7.2.5-3, September 2026) carries
`0512-sound-fixes.patch`, which adds to `cs420x.c`:

    SND_PCI_QUIRK(0x8086, 0x7270, "MacBookAir 7,2", CS4208_MBA6),

`8086:7270` is not a MacBook Air identifier — it is Intel's generic subsystem ID
for the HDA controller, present on this iMac and many other machines. The quirk
therefore applies the MacBook Air pin table to the iMac, which disables pins
`0x1d`/`0x1e` (the real speakers) and enables `0x12` (wired to nothing). Symptom:
`autoconfig ... line_outs=1 (0x12)` in dmesg and total silence. The stock Arch
`linux` kernel is unaffected. Reported: <https://github.com/omacom/omarchy-pkgs/issues/510>.

`options snd_hda_intel model=mbp11,mbp11` pins the `CS4208_MBP11` fixup — the
one upstream 7.2 uses for the iMac 16,1 — which leaves the pins alone. The
`model=` option takes precedence over every quirk table, so this holds on any
kernel. Verified on `linux-omarchy 7.2.5-3`:

    CS4208: picked fixup mbp11 (model specified)
    autoconfig for CS4208: line_outs=2 (0x1d/0x1e/0x0/0x0/0x0) type:speaker

## Speaker wiring

Determined by playing tones into individual slots of the 4-channel PCM:

    converter 0x0a -> pin 0x1d -> LEFT speaker    slot 0 = tweeter, slot 1 = woofer
    converter 0x0b -> pin 0x1e -> RIGHT speaker   slot 2 = tweeter, slot 3 = woofer

The crossover splits the band and feeds both drivers per side, presenting an
ordinary stereo sink ("iMac Built-in Speakers") to applications.

## Install

    ./install.sh
    # then reboot — power_save only applies at module load, and a latched-off
    # amplifier needs a full codec re-init

Tune the crossover by ear:

    ./tune.sh <crossover_hz> <woofer_gain> <tweeter_gain>
    ./tune.sh 800 2.0 0.5      # the defaults

Remove everything with `./uninstall.sh`.

## Gotchas for anyone debugging this further

* **Never run `pactl set-card-profile <card> off`.** Powering the pins down latches
  a speaker amp channel off until the next reboot. Switching *directly* between
  profiles is safe — this was verified deliberately.
* **Check `/sys/class/sound/hwC1D0/power_off_acct` before trusting any negative
  result.** Once an amp channel has latched off, nothing reproduces and every
  measurement becomes noise. Hours were lost to this.
* WirePlumber silently resets the hardware `Master` control to match its own sink
  volume, overriding `amixer sset Master`.
* WirePlumber's default policy re-selects a card profile when port availability
  changes. On jack insert it switched to `analog-stereo`, destroying the
  `analog-surround-40` sink the filter chain targets. Hence
  `api.acp.auto-profile = false`.
* In a PipeWire filter-chain graph a port may be a graph **output** or a **link
  source**, never both. Doing so gives `output port X already used by link, use
  copy` followed by `can't start graph (-16)`, and the chain silently never runs.
* PipeWire ignores **duplicate** channel positions: `[FL,FL,FR,FR]` writes only
  one channel per position and silences the rest. Use distinct positions plus
  `channelmix.upmix`.
* `channelmix.upmix` must be set in `stream.properties` (pipewire-pulse /
  client config), not just on the sink node — sink-node props do not reach
  client streams.

## Status / caveats

* Tested on one machine: iMac16,2, kernel 7.1.8-arch1-3, PipeWire 1.6.8,
  WirePlumber 0.5.15.
* The crossover values (800 Hz, woofer 2.0, tweeter 0.5) were chosen **by ear**,
  not measured. They are a starting point, not a calibrated result.
* Other iMac16,x / CS4208 Macs may share the wiring but this is unverified.
* This combines userspace routing/DSP with an HDA power-save setting. An ALSA
  quirk for SSID `0x106b8100` is an upstream investigation target; it has not
  been demonstrated that one kernel quirk would replace every part of this bundle.

## Licence

Public domain / CC0. Do what you like with it.
