#!/bin/sh
# Built-in speaker + headphone support for the Apple iMac16,2 (21.5" Late 2015)
# and likely other CS4208-equipped Macs whose codec SSID has no kernel quirk.
#
# Run as your normal user; it will call sudo once for the modprobe drop-in.
set -e
cd "$(dirname "$0")"

MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
if [ "$MODEL" != "iMac16,2" ]; then
    echo "WARNING: this machine reports '$MODEL', not iMac16,2."
    echo "The channel mapping and crossover were derived by ear on an iMac16,2."
    echo "Continue only if you know your model has the same speaker wiring."
    printf "Continue? [y/N] "; read -r a; [ "$a" = y ] || [ "$a" = Y ] || exit 1
fi

if ! grep -q CS4208 /proc/asound/card*/codec#* 2>/dev/null; then
    echo "ERROR: no CS4208 codec found. This is not the right machine." >&2
    exit 1
fi

CARD_PATH=$(grep -l CS4208 /proc/asound/card*/codec#* 2>/dev/null | head -1)
PCI=$(basename "$(dirname "$CARD_PATH")")
echo "Found CS4208 on $PCI"
echo "Codec SSID: $(grep -m1 'Subsystem Id' "$CARD_PATH" | awk '{print $3}')"
echo

echo "1/4  Installing modprobe options (power_save=0, pin the correct CS4208 fixup)"
sudo install -m644 config/imac-audio.conf /etc/modprobe.d/imac-audio.conf

echo "2/4  Installing WirePlumber and PipeWire configuration"
mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d" \
         "$HOME/.config/pipewire/pipewire.conf.d" \
         "$HOME/.config/pipewire/pipewire-pulse.conf.d" \
         "$HOME/.config/pipewire/client.conf.d" \
         "$HOME/.config/pipewire/client-rt.conf.d"
install -m644 config/51-imac-speakers.conf  "$HOME/.config/wireplumber/wireplumber.conf.d/"
install -m644 config/60-imac-crossover.conf "$HOME/.config/pipewire/pipewire.conf.d/"
for d in pipewire-pulse client client-rt; do
    install -m644 config/10-imac-upmix.conf "$HOME/.config/pipewire/$d.conf.d/"
done

echo "3/4  Installing the headphone/speaker switcher"
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
install -m755 config/imac-audio-switch         "$HOME/.local/bin/"
install -m644 config/imac-audio-switch.service "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now imac-audio-switch.service

echo "4/4  Restarting the audio stack"
systemctl --user restart pipewire pipewire-pulse wireplumber
sleep 3
systemctl --user restart imac-audio-switch
sleep 2

echo
echo "Done. Select 'iMac Built-in Speakers' as your output."
echo
echo "IMPORTANT: reboot now. power_save=0 only takes effect on module load, and if"
echo "the speaker amp has already latched off it stays off until a full codec re-init."
echo
echo "Tune the crossover by ear with:  ./tune.sh <crossover_hz> <woofer_gain> <tweeter_gain>"
echo "Defaults are 800 2.0 0.5 (chosen by ear on an iMac16,2)."
