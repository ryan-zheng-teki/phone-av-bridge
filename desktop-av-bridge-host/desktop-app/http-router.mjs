export function buildHttpHandler({ routeHandlers, serveStatic, jsonResponse }) {
  return async function handle(req, res) {
    try {
      for (const routeHandler of routeHandlers) {
        if (await routeHandler(req, res)) {
          return;
        }
      }

      if (req.method === 'GET') {
        return serveStatic(req, res);
      }

      return jsonResponse(res, 404, { error: 'Not found' });
    } catch (error) {
      console.warn(`[http] ${req.method} ${req.url} failed: ${error.message || 'Request failed'}`);
      return jsonResponse(res, 400, { error: error.message || 'Request failed' });
    }
  };
}
