import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { buildCatalogReply } from '@/lib/ai-sales';
import { sendWhatsAppText, verifyWhatsAppSignature } from '@/lib/whatsapp';

export const runtime = 'nodejs';

export async function GET(req: Request) {
  const u = new URL(req.url);
  if (
    u.searchParams.get('hub.mode') === 'subscribe' &&
    u.searchParams.get('hub.verify_token') === process.env.WHATSAPP_VERIFY_TOKEN
  ) return new Response(u.searchParams.get('hub.challenge') || '');
  return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
}

export async function POST(req: Request) {
  const rawBody = await req.text();
  if (!verifyWhatsAppSignature(rawBody, req.headers.get('x-hub-signature-256'))) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
  }

  let body: any;
  try { body = JSON.parse(rawBody); } catch { return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 }); }

  if (body.object !== 'whatsapp_business_account') return NextResponse.json({ received: true });

  for (const entry of body.entry || []) {
    for (const change of entry.changes || []) {
      const value = change.value || {};
      const phoneNumberId = value.metadata?.phone_number_id;
      if (!phoneNumberId) continue;

      const shop = await db.shop.findFirst({ where: { whatsappPhoneNumberId: phoneNumberId, isActive: true } });
      if (!shop) continue;

      for (const msg of value.messages || []) {
        const providerMessageId = msg.id;
        if (!providerMessageId) continue;

        try {
          await db.whatsappEvent.create({
            data: { shopId: shop.id, providerMessageId, eventType: msg.type || 'message', payload: msg },
          });
        } catch {
          // WhatsApp retries the same event. Unique providerMessageId makes processing idempotent.
          continue;
        }

        if (msg.type !== 'text' || !msg.from) continue;
        const text = String(msg.text?.body || '').trim();
        if (!text) continue;

        const conversation = await db.whatsappConversation.upsert({
          where: { shopId_customerPhone: { shopId: shop.id, customerPhone: msg.from } },
          create: { shopId: shop.id, customerPhone: msg.from, customerName: value.contacts?.[0]?.profile?.name || undefined, unreadCount: 1 },
          update: { lastMessageAt: new Date(), unreadCount: { increment: 1 }, customerName: value.contacts?.[0]?.profile?.name || undefined },
        });

        await db.whatsappMessage.create({
          data: { conversationId: conversation.id, shopId: shop.id, direction: 'IN', body: text, providerMessageId, status: 'DELIVERED' },
        });

        if (!shop.botEnabled || conversation.mode === 'HUMAN') continue;

        const normalized = text.toLowerCase();
        const handoff = ['human', 'agent', 'staff', 'representative', 'person', 'support'].some((word) => normalized.includes(word)) ||
          shop.handoffKeywords.some((word) => normalized.includes(word.toLowerCase()));

        if (handoff) {
          await db.whatsappConversation.update({ where: { id: conversation.id }, data: { mode: 'HUMAN' } });
          const reply = 'I’m connecting you with a member of our team now. Please hold on a moment.';
          const sent = await sendWhatsAppText(msg.from, reply, shop.whatsappPhoneNumberId || undefined);
          await db.whatsappMessage.create({ data: { conversationId: conversation.id, shopId: shop.id, direction: 'OUT', body: reply, status: 'SENT', providerMessageId: sent?.messages?.[0]?.id } });
          continue;
        }

        try {
          const reply = await buildCatalogReply(shop.id, text);
          if (!reply) continue;
          const finalReply = reply === 'HANDOFF_REQUIRED' ? 'I’m connecting you with a member of our team now. Please hold on a moment.' : reply;
          if (reply === 'HANDOFF_REQUIRED') await db.whatsappConversation.update({ where: { id: conversation.id }, data: { mode: 'HUMAN' } });
          const sent = await sendWhatsAppText(msg.from, finalReply, shop.whatsappPhoneNumberId || undefined);
          await db.whatsappMessage.create({ data: { conversationId: conversation.id, shopId: shop.id, direction: 'OUT', body: finalReply, status: 'SENT', providerMessageId: sent?.messages?.[0]?.id } });
        } catch (error) {
          console.error('WhatsApp AI reply failed', error);
        }
      }
    }
  }

  return NextResponse.json({ received: true });
}
