#!/bin/sh
# Remove the iMac16,2 audio configuration.
set -e
systemctl --user disable --now imac-audio-switch.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/imac-audio-switch.service" \
      "$HOME/.local/bin/imac-audio-switch" \
      "$HOME/.config/wireplumber/wireplumber.conf.d/51-imac-speakers.conf" \
      "$HOME/.config/pipewire/pipewire.conf.d/60-imac-crossover.conf" \
      "$HOME/.config/pipewire/pipewire-pulse.conf.d/10-imac-upmix.conf" \
      "$HOME/.config/pipewire/client.conf.d/10-imac-upmix.conf" \
      "$HOME/.config/pipewire/client-rt.conf.d/10-imac-upmix.conf"
sudo rm -f /etc/modprobe.d/imac-audio.conf
systemctl --user daemon-reload
systemctl --user restart pipewire pipewire-pulse wireplumber
echo "Removed. Reboot to restore stock behaviour."
