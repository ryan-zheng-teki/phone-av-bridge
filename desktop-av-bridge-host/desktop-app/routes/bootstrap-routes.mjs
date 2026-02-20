import { runPreflight } from '../../core/preflight-service.mjs';

export function createBootstrapRoutes({
  controller,
  bootstrap,
  qrTokenService,
  getPreflightReport,
  setPreflightReport,
  readBody,
  jsonResponse,
}) {
  return async function handleBootstrapRoute(req, res) {
    if (req.method === 'GET' && req.url === '/health') {
      jsonResponse(res, 200, { ok: true, service: 'phone-av-bridge-host' });
      return true;
    }

    if (req.method === 'GET' && req.url === '/api/status') {
      jsonResponse(res, 200, {
        status: controller.getStatus(),
        preflight: getPreflightReport(),
        bootstrap,
      });
      return true;
    }

    if (req.method === 'GET' && req.url === '/api/bootstrap') {
      jsonResponse(res, 200, { bootstrap });
      return true;
    }

    if (req.method === 'POST' && req.url === '/api/bootstrap/qr-token') {
      const qrToken = await qrTokenService.issueQrToken();
      console.log(`[qr] issued token exp=${qrToken.expiresAt} host=${bootstrap.baseUrl} remote=${req.socket.remoteAddress || 'unknown'}`);
      jsonResponse(res, 200, { qrToken });
      return true;
    }

    if (req.method === 'POST' && req.url === '/api/bootstrap/qr-redeem') {
      const body = await readBody(req);
      const tokenPreview = typeof body.token === 'string' ? `${body.token.slice(0, 6)}…` : 'none';
      let redeemed;
      try {
        redeemed = qrTokenService.redeemQrToken(body.token);
      } catch (error) {
        console.warn(`[qr] redeem failed token=${tokenPreview} remote=${req.socket.remoteAddress || 'unknown'} error=${error.message}`);
        throw error;
      }
      console.log(`[qr] redeem success token=${tokenPreview} remote=${req.socket.remoteAddress || 'unknown'} baseUrl=${redeemed.bootstrap.baseUrl}`);
      jsonResponse(res, 200, redeemed);
      return true;
    }

    if (req.method === 'POST' && req.url === '/api/preflight') {
      const preflightReport = await runPreflight(process.platform);
      setPreflightReport(preflightReport);
      jsonResponse(res, 200, { preflight: preflightReport });
      return true;
    }

    return false;
  };
}
