# Project Runbook (Agent Notes)

## Real-Device E2E Startup (Always)

When testing with a physical Android device, always start host with explicit network settings:

```bash
cd /Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host
HOST_BIND=0.0.0.0 ADVERTISED_HOST=<LAN_IP> PORT=8787 node desktop-app/server.mjs
```

- `HOST_BIND=0.0.0.0`: host API + discovery listen on LAN interfaces.
- `ADVERTISED_HOST=<LAN_IP>`: Android sees/selects the correct host in pairing dialog.
- `PORT=8787`: keep API endpoint stable for app and scripts.

Validate startup:

```bash
curl -s http://127.0.0.1:8787/health
curl -s http://127.0.0.1:8787/api/bootstrap | jq '.bootstrap.baseUrl,.bootstrap.pairingCode'
```

## Pairing Selection Rule

- If Android shows multiple hosts, choose the host whose URL matches `<LAN_IP>:8787`.
- Do not rely on auto-select when multiple LAN hosts are online.

## Loopback-Only Debug Mode (Optional)

Use this only for USB reverse tests, not normal LAN pairing:

```bash
adb reverse tcp:8787 tcp:8787
HOST_BIND=0.0.0.0 ADVERTISED_HOST=127.0.0.1 PORT=8787 node desktop-app/server.mjs
```

## If App Keeps Pairing Wrong Host

```bash
adb shell pm clear org.autobyteus.phoneavbridge
```

## macOS Camera App Launch Path (Avoid Old Copy)

- Preferred local build/install command:

```bash
cd /Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension
./scripts/build-signed-local.sh
```

- The script cleans local derived data and installs to `~/Applications/PhoneAVBridgeCamera.app`.
- It also prunes duplicate `/Applications/PhoneAVBridgeCamera.app` copies by default.
- If both `/Applications/PhoneAVBridgeCamera.app` and `~/Applications/PhoneAVBridgeCamera.app` still exist, do not use `open -a PhoneAVBridgeCamera`.
- `open -a` may select `/Applications` and launch an older bundle.
- Always launch the intended bundle with explicit path:

```bash
pkill -f 'PhoneAVBridgeCamera.app/Contents/MacOS/PhoneAVBridgeCamera' || true
open "$HOME/Applications/PhoneAVBridgeCamera.app"
```

- Verify the actual running path:

```bash
ps -ax -o pid,etime,args | rg 'PhoneAVBridgeCamera.app/Contents/MacOS/PhoneAVBridgeCamera' | rg -v rg
```
