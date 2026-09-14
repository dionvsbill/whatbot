import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { db } from '@/lib/db';
import { attributePaidOrder } from '@/lib/earnings';

export async function POST(req: Request) {
  const raw = await req.text();
  const sig = req.headers.get('x-paystack-signature');
  const key = process.env.PAYSTACK_SECRET_KEY;
  if (!key || !sig) return NextResponse.json({ error: 'Webhook not configured' }, { status: 400 });
  const expected = crypto.createHmac('sha512', key).update(raw).digest('hex');
  if (sig.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
  }

  let event: any;
  try { event = JSON.parse(raw); } catch { return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 }); }
  if (event.event !== 'charge.success' || !event.data?.reference) return NextResponse.json({ received: true });

  const reference = String(event.data.reference);
  const order = await db.order.findUnique({ where: { paystackReference: reference } });
  if (!order) return NextResponse.json({ received: true });

  if (order.status === 'PENDING_PAYMENT') {
    await db.order.update({ where: { id: order.id }, data: { status: 'PAID' } });
  }

  const code = await db.referralConversion.findUnique({ where: { orderId: order.id }, select: { code: true } });
  if (!code) {
    const conversionCode = await db.$queryRaw<Array<{ code: string | null }>>`
      SELECT code FROM "ReferralClick"
      WHERE "createdAt" <= ${new Date()} AND code IS NOT NULL
      AND ("earningProfileId" IN (SELECT id FROM "EarningProfile" WHERE "userId" <> ${order.customerId})
        OR "partnerId" IS NOT NULL)
      ORDER BY "createdAt" DESC LIMIT 1
    `;
    const referralCode = conversionCode[0]?.code;
    if (referralCode) await attributePaidOrder(order.id, referralCode);
  }

  return NextResponse.json({ received: true });
}
