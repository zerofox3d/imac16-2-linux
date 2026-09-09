#!/bin/sh
# usage: tune.sh <crossover_hz> <woofer_gain> <tweeter_gain>
# e.g.   tune.sh 2500 2.0 0.9
P="$HOME/.config/pipewire/pipewire.conf.d/60-imac-crossover.conf"
sed -i -E "s/Freq = [0-9]+/Freq = $1/g" "$P"
sed -i -E "s/(name = g[LR]  label = linear      control = \{ Mult = )[0-9.]+/\1$2/g" "$P"
sed -i -E "s/(name = t[LR]  label = linear      control = \{ Mult = )[0-9.]+/\1$3/g" "$P"
systemctl --user restart pipewire pipewire-pulse
sleep 4
pactl set-default-sink imac_speakers 2>/dev/null
pactl set-sink-volume imac_speakers 55% 2>/dev/null
pactl set-sink-mute imac_speakers 0 2>/dev/null
pactl set-sink-mute alsa_output.pci-0000_00_1b.0.analog-surround-40 0 2>/dev/null
pactl set-sink-volume alsa_output.pci-0000_00_1b.0.analog-surround-40 70% 2>/dev/null
echo "crossover=$1 Hz  woofer=$2  tweeter=$3"
