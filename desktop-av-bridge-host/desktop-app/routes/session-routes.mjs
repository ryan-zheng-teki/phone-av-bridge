export function createSessionRoutes({
  controller,
  pairingCode,
  readBody,
  jsonResponse,
}) {
  return async function handleSessionRoute(req, res) {
    if (req.method === 'GET' && req.url === '/api/speaker/stream') {
      controller.attachSpeakerStream(res);
      return true;
    }

    if (req.method === 'POST' && req.url === '/api/pair') {
      const body = await readBody(req);
      if ((body.pairCode || '') !== pairingCode) {
        throw new Error('Invalid pair code.');
      }
      const status = await controller.pairHost(body.pairCode || '', {
        deviceName: typeof body.deviceName === 'string' ? body.deviceName.trim() : undefined,
        deviceId: typeof body.deviceId === 'string' ? body.deviceId.trim() : undefined,
      });
      jsonResponse(res, 200, { status });
      return true;
    }

    if (req.method === 'POST' && req.url === '/api/presence') {
      const body = await readBody(req);
      const status = controller.notePhonePresence({
        deviceName: typeof body.deviceName === 'string' ? body.deviceName.trim() : undefined,
        deviceId: typeof body.deviceId === 'string' ? body.deviceId.trim() : undefined,
      });
      jsonResponse(res, 200, { status });
      return true;
    }

    if (req.method === 'POST' && req.url === '/api/unpair') {
      const status = await controller.unpairHost();
      jsonResponse(res, 200, { status });
      return true;
    }

    if (req.method === 'POST' && req.url === '/api/toggles') {
      const body = await readBody(req);
      const status = await controller.applyResourceState({
        camera: !!body.camera,
        microphone: !!body.microphone,
        speaker: !!body.speaker,
        cameraLens: typeof body.cameraLens === 'string' ? body.cameraLens.trim() : undefined,
        cameraOrientationMode: typeof body.cameraOrientationMode === 'string' ? body.cameraOrientationMode.trim() : undefined,
        cameraStreamUrl: typeof body.cameraStreamUrl === 'string' ? body.cameraStreamUrl.trim() : undefined,
        deviceName: typeof body.deviceName === 'string' ? body.deviceName.trim() : undefined,
        deviceId: typeof body.deviceId === 'string' ? body.deviceId.trim() : undefined,
      });
      jsonResponse(res, 200, { status });
      return true;
    }

    return false;
  };
}
