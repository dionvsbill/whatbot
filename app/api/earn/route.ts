import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { db } from '@/lib/db';
import { verifySession } from '@/lib/security';
import { getOrCreateEarningProfile } from '@/lib/earnings';

export async function GET() {
  const userId = verifySession(cookies().get('whatbot_session')?.value);
  if (!userId) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  const profile = await getOrCreateEarningProfile(userId);
  const [commissions, partners, campaigns] = await Promise.all([
    db.commission.findMany({ where: { earningProfileId: profile.id }, orderBy: { createdAt: 'desc' }, take: 20 }),
    db.affiliatePartner.findMany({ where: { userId }, include: { program: { include: { shop: true } } }, orderBy: { createdAt: 'desc' }, take: 20 }),
    db.creatorCampaign.findMany({ where: { status: 'ACTIVE' }, include: { shop: true }, orderBy: { createdAt: 'desc' }, take: 20 }),
  ]);
  return NextResponse.json({ profile, commissions, partners, campaigns });
}

export async function POST(req: Request) {
  const userId = verifySession(cookies().get('whatbot_session')?.value);
  if (!userId) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  const body = await req.json().catch(() => ({}));
  if (body.action !== 'payout') return NextResponse.json({ error: 'Invalid action' }, { status: 400 });
  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount < 20) return NextResponse.json({ error: 'Minimum payout is GHS 20' }, { status: 400 });
  const profile = await getOrCreateEarningProfile(userId);
  if (Number(profile.availableBalance) < amount) return NextResponse.json({ error: 'Insufficient available balance' }, { status: 400 });
  const payout = await db.$transaction(async tx => {
    const p = await tx.earningPayoutRequest.create({ data: { earningProfileId: profile.id, userId, amount, destination: body.destination ? String(body.destination).slice(0, 100) : undefined } });
    await tx.earningProfile.update({ where: { id: profile.id }, data: { availableBalance: { decrement: amount } } });
    return p;
  });
  return NextResponse.json({ payout });
}
