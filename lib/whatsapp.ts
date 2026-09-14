import { createHmac, timingSafeEqual } from 'crypto';

const graphVersion = process.env.WHATSAPP_GRAPH_VERSION || 'v20.0';
const graphBase = `https://graph.facebook.com/${graphVersion}`;

export function verifyWhatsAppSignature(rawBody: string, signature: string | null) {
  const secret = process.env.WHATSAPP_APP_SECRET;
  if (!secret || !signature?.startsWith('sha256=')) return false;
  const expected = Buffer.from(`sha256=${createHmac('sha256', secret).update(rawBody).digest('hex')}`);
  const received = Buffer.from(signature);
  return expected.length === received.length && timingSafeEqual(expected, received);
}

export async function sendWhatsAppText(to: string, body: string, phoneNumberId?: string) {
  const token = process.env.WHATSAPP_ACCESS_TOKEN;
  const id = phoneNumberId || process.env.WHATSAPP_PHONE_ID;
  if (!token || !id) throw new Error('WhatsApp Cloud API is not configured');

  const response = await fetch(`${graphBase}/${id}/messages`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to,
      type: 'text',
      text: { preview_url: true, body },
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data?.error?.message || 'WhatsApp message failed');
  return data;
}
