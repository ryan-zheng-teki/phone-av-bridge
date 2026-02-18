# Future-State Runtime Call Stacks (Debug-Trace Style)

## Design Basis
- Scope Classification: `Medium`
- Call Stack Version: `v2`
- Requirements: `tickets/in-progress/project-naming-refactor/requirements.md` (status `Refined`)
- Source Artifact: `tickets/in-progress/project-naming-refactor/proposed-design.md`
- Source Design Version: `v1`
- Referenced Sections: `Change Inventory`, `Naming Decisions`, `Use-Case Coverage Matrix`

## Future-State Modeling Rule (Mandatory)
- This models target naming-aligned behavior after refactor completion.

## Use Case Index (Stable IDs)
| use_case_id | Requirement | Use Case Name | Coverage Target (Primary/Fallback/Error) |
| --- | --- | --- | --- |
| UC-001 | R-001/R-002 | Module/folder naming is canonical | Yes/N/A/N/A |
| UC-002 | R-001 | User-visible app naming is canonical | Yes/N/A/N/A |
| UC-003 | R-003 | Discovery and pairing work with new identifiers | Yes/Yes/Yes |
| UC-004 | R-002/R-004 | Host-to-bridge runtime path wiring remains valid | Yes/Yes/Yes |
| UC-005 | R-001 | macOS camera/audio artifacts and bundle IDs are fully renamed | Yes/Yes/Yes |

## Transition Notes
- Old names are removed from active runtime paths in one release.
- Historical records under `tickets/done` keep legacy naming as archival context.

## Use Case: UC-001 [Canonical Module Naming]

### Goal
Active runtime module paths use canonical `phone-av-bridge` vocabulary.

### Preconditions
Refactor branch applied.

### Expected Outcome
Build/test scripts and imports resolve renamed module paths.

### Primary Runtime Call Stack
```text
[ENTRY] repository:rename-modules
├── phone-resource-companion/:mv android-resource-companion -> android-phone-av-bridge [IO]
├── phone-resource-companion/:mv host-resource-agent -> desktop-av-bridge-host [IO]
├── phone-resource-companion/:mv phone-ip-webcam-bridge -> phone-av-camera-bridge-runtime [IO]
├── desktop-av-bridge-host/package.json:scripts update paths [STATE]
└── repository:rg-scan old module names absent in active runtime [IO]
```

### Branching / Fallback Paths
```text
[FALLBACK] if script reference broken after path move
[ENTRY] desktop-av-bridge-host/tests/docker/docker-compose.linux-e2e.yml:update build context path [STATE]
```

```text
[ERROR] unresolved path at runtime
desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs:startCamera(...)
└── throw Error("Camera bridge failed to start: ...")
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `N/A`

## Use Case: UC-002 [Canonical User-Facing Naming]

### Goal
Android and host UI show `Phone AV Bridge` naming.

### Preconditions
String resources and host static UI updated.

### Expected Outcome
Users see one product name across phone and desktop.

### Primary Runtime Call Stack
```text
[ENTRY] android-phone-av-bridge/app/src/main/res/values/strings.xml [STATE]
├── app_name/title/notification strings -> "Phone AV Bridge"
└── pair guidance string -> "Phone AV Bridge Host"

[ENTRY] desktop-av-bridge-host/desktop-app/static/index.html [STATE]
└── title/h1 -> "Phone AV Bridge Host"
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `N/A`

## Use Case: UC-003 [Discovery + Pairing with New Identifiers]

### Goal
Android discovers and pairs host using renamed discovery/service identifiers.

### Preconditions
Host and Android constants updated to new values.

### Expected Outcome
Pairing succeeds and status API returns expected service name.

### Primary Runtime Call Stack
```text
[ENTRY] android-phone-av-bridge/.../network/HostDiscoveryClient.kt:discoverHost(...)
├── send UDP probe "PHONE_AV_BRIDGE_DISCOVER_V1" [IO]
├── receive response JSON [IO]
└── validate payload.service == "phone-av-bridge" [STATE]

[ENTRY] desktop-av-bridge-host/desktop-app/server.mjs:createApp(...)
├── DISCOVERY_MAGIC = "PHONE_AV_BRIDGE_DISCOVER_V1" [STATE]
├── bootstrap.service = "phone-av-bridge" [STATE]
└── POST /api/pair -> SessionController.pairHost(...) [ASYNC]
```

### Branching / Fallback Paths
```text
[FALLBACK] discovery timeout
HostDiscoveryClient.kt:discoverHost(...)
└── throw PairingFailedException("Host not found")
```

```text
[ERROR] pair code mismatch
desktop-av-bridge-host/desktop-app/server.mjs:POST /api/pair
└── throw Error("Invalid pair code.")
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-005 [macOS Artifact + Bundle-ID Rebrand]

### Goal
Camera/audio artifacts and identifiers are aligned to `Phone AV Bridge` names across build, install, and runtime preflight.

### Primary Runtime Call Stack
```text
[ENTRY] macos-camera-extension/samplecamera.xcodeproj/project.pbxproj [STATE]
├── PRODUCT_BUNDLE_IDENTIFIER = org.autobyteus.phoneavbridge.camera [STATE]
├── extension PRODUCT_BUNDLE_IDENTIFIER = org.autobyteus.phoneavbridge.camera.extension [STATE]
└── PRODUCT_NAME = PhoneAVBridgeCamera [STATE]

[ENTRY] desktop-av-bridge-host/macos-audio-driver/scripts/build-driver-local.sh [STATE]
├── OUT_DIR = PhoneAVBridgeAudio.driver [STATE]
├── kPlugIn_BundleID = org.autobyteus.phoneavbridge.audio.driver [STATE]
└── kDriver_Name = PhoneAVBridgeAudio [STATE]
```

### Branching / Fallback Paths
```text
[FALLBACK] old legacy driver still installed
osascript admin shell
└── remove /Library/Audio/Plug-Ins/HAL/PRCAudio.driver + restart coreaudiod [IO]
```

```text
[ERROR] extension not yet approved under new identifier
desktop-av-bridge-host/core/preflight-service.mjs:runPreflight()
└── check macos_camera_extension_state = warn with remediation to open PhoneAVBridgeCamera.app [STATE]
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-004 [Host Bridge Runtime Wiring After Rename]

### Goal
Host camera adapter still launches bridge runtime script after module rename.

### Preconditions
Host adapter script path updated to renamed bridge module.

### Expected Outcome
Camera route can start with renamed path.

### Primary Runtime Call Stack
```text
[ENTRY] desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs:startCamera(...)
├── repoRoot resolve [STATE]
├── scriptPath = repoRoot/phone-av-camera-bridge-runtime/bin/run-bridge.sh [STATE]
├── spawn(scriptPath, env...) [ASYNC][IO]
└── health probe validates process running [STATE]
```

### Branching / Fallback Paths
```text
[FALLBACK] auto mode without v4l2 device
bridge-runner.mjs:#resolveBackend()
└── select linux-null-emulator backend [STATE]
```

```text
[ERROR] bridge process exits during startup
bridge-runner.mjs:startCamera(...)
└── stopCamera(); throw Error("Camera bridge failed to start: ...")
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`
