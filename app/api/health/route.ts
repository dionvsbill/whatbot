import { NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET() {
  const startedAt = Date.now();
  try {
    await db.$queryRaw`SELECT 1`;
    return NextResponse.json({
      ok: true,
      service: 'whatbot',
      database: 'connected',
      providers: {
        paystack: Boolean(process.env.PAYSTACK_SECRET_KEY),
        whatsapp: Boolean(process.env.WHATSAPP_ACCESS_TOKEN && process.env.WHATSAPP_PHONE_ID),
        cloudinary: Boolean(process.env.CLOUDINARY_CLOUD_NAME && process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET),
        amazon: Boolean(process.env.AMAZON_ACCESS_KEY && process.env.AMAZON_SECRET_KEY && process.env.AMAZON_PARTNER_TAG),
      },
      latencyMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  } catch {
    return NextResponse.json(
      { ok: false, service: 'whatbot', database: 'unavailable', latencyMs: Date.now() - startedAt },
      { status: 503 },
    );
  }
}
