import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { verifySession } from '@/lib/security';
import { sendWhatsAppText } from '@/lib/whatsapp';

export async function POST(req: Request) {
  const userId = verifySession(req.headers.get('cookie')?.match(/(?:^|;\s*)whatbot_session=([^;]+)/)?.[1]);
  if (!userId) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { to, message, phoneNumberId, shopId } = await req.json();
    if (!shopId) return NextResponse.json({ error: 'shopId is required' }, { status: 400 });
    const user = await db.user.findUnique({ where: { id: userId }, select: { role: true } });
    const shop = await db.shop.findUnique({ where: { id: shopId }, select: { ownerId: true, whatsappPhoneNumberId: true } });
    if (!user || !shop || (user.role !== 'SUPER_ADMIN' && shop.ownerId !== userId)) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }
    if (!/^\+?[1-9]\d{7,14}$/.test(String(to || ''))) return NextResponse.json({ error: 'Invalid recipient phone number' }, { status: 400 });
    if (!String(message || '').trim()) return NextResponse.json({ error: 'Message is required' }, { status: 400 });
    const result = await sendWhatsAppText(String(to), String(message).trim(), shop.whatsappPhoneNumberId || phoneNumberId);
    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : 'WhatsApp send failed' }, { status: 502 });
  }
}
