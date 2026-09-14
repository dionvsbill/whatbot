import { NextResponse } from 'next/server';
import { sendWhatsAppText } from '@/lib/whatsapp';

export async function POST(req: Request) {
  try {
    const { to, message, phoneNumberId } = await req.json();
    if (!/^\+?[1-9]\d{7,14}$/.test(String(to || ''))) {
      return NextResponse.json({ error: 'Invalid recipient phone number' }, { status: 400 });
    }
    if (!String(message || '').trim()) return NextResponse.json({ error: 'Message is required' }, { status: 400 });
    const result = await sendWhatsAppText(String(to), String(message).trim(), phoneNumberId);
    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : 'WhatsApp send failed' }, { status: 502 });
  }
}
