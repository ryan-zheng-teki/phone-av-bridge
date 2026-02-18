# Investigation Notes

## Context
- Symptom: Android app stayed at pairing in-progress / host not selected while PRCCamera showed `Enabled`.
- User expectation: one integrated macOS product, no manual second app startup.

## Evidence
- PRCCamera log showed camera extension activation only; it did not expose host discovery service.
- Android discovery client requires UDP probe/response on `39888` and HTTP host API on `8787`.
- Host discovery/service is implemented by Host Resource Agent (`host-resource-agent/linux-app/server.mjs`), not by PRCCamera extension app.
- Runtime check confirmed no listeners on `8787/39888` when only PRCCamera was open.

## Root Cause
- Product flow split across two apps, but PRCCamera UI did not ensure Host Resource Agent was running.
- Auto-start attempt initially missed `~/Applications/Host Resource Agent.app` resolution under sandboxed home-path behavior.

## Resolution Direction
- Integrate host-bridge lifecycle awareness into PRCCamera UI:
  - active health check to `http://127.0.0.1:8787/health`,
  - auto-start Host Resource Agent if offline,
  - explicit in-app status + manual start/open controls,
  - robust app location detection via bundle-id lookup + explicit path fallbacks.
