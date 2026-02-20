import crypto from 'node:crypto';
import QRCode from 'qrcode';

export const DEFAULT_QR_TOKEN_TTL_MS = 2 * 60 * 1000;
export const DEFAULT_QR_IMAGE_SIZE = 360;

export function createQrTokenService({
  bootstrap,
  qrTokenTtlMs = DEFAULT_QR_TOKEN_TTL_MS,
  qrImageSize = DEFAULT_QR_IMAGE_SIZE,
  now = () => Date.now(),
  randomBytes = crypto.randomBytes,
  qrCodeToDataUrl = QRCode.toDataURL,
} = {}) {
  if (!bootstrap) {
    throw new Error('bootstrap is required');
  }

  const qrTokenRegistry = new Map();

  function cleanupQrTokens(currentTimeMs = now()) {
    for (const [token, entry] of qrTokenRegistry.entries()) {
      if (!entry || Number.isNaN(entry.expiresAt) || entry.expiresAt <= currentTimeMs) {
        qrTokenRegistry.delete(token);
      }
    }
  }

  async function issueQrToken() {
    const currentTimeMs = now();
    cleanupQrTokens(currentTimeMs);
    const token = randomBytes(24).toString('base64url');
    const expiresAtMs = currentTimeMs + Math.max(1000, Number(qrTokenTtlMs) || DEFAULT_QR_TOKEN_TTL_MS);
    qrTokenRegistry.set(token, { expiresAt: expiresAtMs, used: false });

    const payload = {
      service: 'phone-av-bridge',
      version: 1,
      token,
      baseUrl: bootstrap.baseUrl,
      hostId: bootstrap.hostId,
      displayName: bootstrap.displayName,
    };
    const payloadText = JSON.stringify(payload);

    let qrImageDataUrl = null;
    try {
      qrImageDataUrl = await qrCodeToDataUrl(payloadText, {
        errorCorrectionLevel: 'M',
        margin: 1,
        width: qrImageSize,
      });
    } catch {
      qrImageDataUrl = null;
    }

    return {
      token,
      expiresAt: new Date(expiresAtMs).toISOString(),
      payload,
      payloadText,
      qrImageDataUrl,
    };
  }

  function redeemQrToken(token) {
    const normalized = typeof token === 'string' ? token.trim() : '';
    if (!normalized) {
      throw new Error('QR token is required.');
    }

    const currentTimeMs = now();
    cleanupQrTokens(currentTimeMs);
    const entry = qrTokenRegistry.get(normalized);
    if (!entry) {
      throw new Error('QR token is invalid or expired.');
    }
    if (entry.used) {
      throw new Error('QR token has already been used.');
    }
    if (entry.expiresAt <= currentTimeMs) {
      qrTokenRegistry.delete(normalized);
      throw new Error('QR token is invalid or expired.');
    }

    entry.used = true;
    qrTokenRegistry.set(normalized, entry);
    return { bootstrap };
  }

  return {
    issueQrToken,
    redeemQrToken,
  };
}
