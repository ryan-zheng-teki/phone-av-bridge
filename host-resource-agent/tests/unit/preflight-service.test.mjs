import test from 'node:test';
import assert from 'node:assert/strict';
import { runPreflight } from '../../core/preflight-service.mjs';

test('preflight returns structured report for current platform', async () => {
  const report = await runPreflight(process.platform);

  assert.ok(report.platform);
  assert.ok(report.status);
  assert.ok(Array.isArray(report.checks));
  assert.ok(report.checks.length >= 1);

  const ffmpegCheck = report.checks.find((check) => check.id === 'ffmpeg');
  assert.ok(ffmpegCheck, 'ffmpeg check should be present');
  assert.ok(['pass', 'fail'].includes(ffmpegCheck.status));
});
