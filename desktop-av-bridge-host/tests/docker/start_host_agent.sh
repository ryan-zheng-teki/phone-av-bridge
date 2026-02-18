#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/tmp/host-agent-home}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime}"
mkdir -p "${HOME}" "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

if ! pulseaudio --check >/dev/null 2>&1; then
  pulseaudio --daemonize=yes --exit-idle-time=-1 --log-target=stderr
fi

for _ in $(seq 1 20); do
  if pactl info >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

if ! pactl list short sinks | awk '{print $2}' | grep -qx 'pavb_sink'; then
  pactl load-module module-null-sink sink_name=pavb_sink sink_properties=device.description=PhoneAVBridge_Sink >/dev/null
fi

pactl set-default-sink pavb_sink >/dev/null 2>&1 || true
pactl set-default-source pavb_sink.monitor >/dev/null 2>&1 || true

# Keep a quiet but non-silent output signal so speaker-stream validation can measure audio.
ffmpeg -hide_banner -loglevel error -re \
  -f lavfi -i "sine=frequency=660:sample_rate=48000" \
  -af "volume=0.02" \
  -ac 1 -ar 48000 \
  -f pulse pavb_sink >/tmp/pavb-tone.log 2>&1 &

exec node desktop-app/server.mjs
