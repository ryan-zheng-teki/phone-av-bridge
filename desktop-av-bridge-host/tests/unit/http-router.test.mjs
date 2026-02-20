import test from 'node:test';
import assert from 'node:assert/strict';
import { buildHttpHandler } from '../../desktop-app/http-router.mjs';

test('router dispatches to first matching route handler', async () => {
  const calls = [];
  const handler = buildHttpHandler({
    routeHandlers: [
      async (req) => {
        calls.push(`first:${req.url}`);
        return true;
      },
      async () => {
        calls.push('second');
        return true;
      },
    ],
    serveStatic: async () => {
      calls.push('static');
    },
    jsonResponse: () => {
      calls.push('json');
    },
  });

  await handler({ method: 'GET', url: '/api/bootstrap' }, {});
  assert.deepEqual(calls, ['first:/api/bootstrap']);
});

test('router falls back to static serving for unmatched GET', async () => {
  const calls = [];
  const handler = buildHttpHandler({
    routeHandlers: [
      async () => false,
    ],
    serveStatic: async () => {
      calls.push('static');
    },
    jsonResponse: () => {
      calls.push('json');
    },
  });

  await handler({ method: 'GET', url: '/index.html' }, {});
  assert.deepEqual(calls, ['static']);
});

test('router returns 404 for unmatched non-GET requests', async () => {
  const payloads = [];
  const handler = buildHttpHandler({
    routeHandlers: [
      async () => false,
    ],
    serveStatic: async () => {
      throw new Error('should not be called');
    },
    jsonResponse: (_res, status, payload) => {
      payloads.push({ status, payload });
    },
  });

  await handler({ method: 'POST', url: '/missing' }, {});
  assert.deepEqual(payloads, [{ status: 404, payload: { error: 'Not found' } }]);
});

test('router catches route errors and returns 400', async () => {
  const payloads = [];
  const warnings = [];
  const originalWarn = console.warn;
  console.warn = (message) => {
    warnings.push(message);
  };

  try {
    const handler = buildHttpHandler({
      routeHandlers: [
        async () => {
          throw new Error('boom');
        },
      ],
      serveStatic: async () => {
        throw new Error('should not be called');
      },
      jsonResponse: (_res, status, payload) => {
        payloads.push({ status, payload });
      },
    });

    await handler({ method: 'POST', url: '/api/pair' }, {});
  } finally {
    console.warn = originalWarn;
  }

  assert.equal(payloads.length, 1);
  assert.deepEqual(payloads[0], { status: 400, payload: { error: 'boom' } });
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /\[http\] POST \/api\/pair failed: boom/);
});
