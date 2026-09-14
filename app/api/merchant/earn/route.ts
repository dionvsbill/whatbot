import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { db } from '@/lib/db';
import { verifySession } from '@/lib/security';

async function shopForUser() {
  const userId = verifySession(cookies().get('whatbot_session')?.value);
  if (!userId) return null;
  return db.shop.findUnique({ where: { ownerId: userId } });
}

export async function GET() {
  const shop = await shopForUser();
  if (!shop) return NextResponse.json({ error: 'Shop not found' }, { status: 404 });
  const [programs, campaigns, payouts] = await Promise.all([
    db.affiliateProgram.findMany({ where: { shopId: shop.id }, include: { _count: { select: { partners: true, clicks: true, commissions: true } } }, orderBy: { createdAt: 'desc' } }),
    db.creatorCampaign.findMany({ where: { shopId: shop.id }, include: { _count: { select: { applications: true } } }, orderBy: { createdAt: 'desc' } }),
    db.commission.aggregate({ where: { program: { shopId: shop.id } }, _sum: { amount: true, platformFee: true } }),
  ]);
  return NextResponse.json({ programs, campaigns, totals: payouts._sum });
}

export async function POST(req: Request) {
  const shop = await shopForUser();
  if (!shop) return NextResponse.json({ error: 'Shop not found' }, { status: 404 });
  const body = await req.json().catch(() => ({}));
  if (body.type === 'program') {
    const commissionRate = Math.max(0, Math.min(50, Number(body.commissionRate ?? 5)));
    const cashbackRate = Math.max(0, Math.min(50, Number(body.cashbackRate ?? 0)));
    const program = await db.affiliateProgram.create({ data: { shopId: shop.id, name: String(body.name || 'Affiliate Program').slice(0, 100), description: body.description ? String(body.description).slice(0, 1000) : undefined, commissionRate, cashbackRate, fixedReward: body.fixedReward != null ? Number(body.fixedReward) : undefined, maxReward: body.maxReward != null ? Number(body.maxReward) : undefined, status: 'DRAFT' } });
    return NextResponse.json({ program });
  }
  if (body.type === 'creator') {
    const campaign = await db.creatorCampaign.create({ data: { shopId: shop.id, title: String(body.title || 'Creator Campaign').slice(0, 120), description: String(body.description || '').slice(0, 2000), deliverable: body.deliverable ? String(body.deliverable).slice(0, 1000) : undefined, budget: Number(body.budget || 0), rewardPerCreator: Number(body.rewardPerCreator || 0), maxCreators: Math.max(1, Math.min(1000, Number(body.maxCreators || 10))), status: 'DRAFT' } });
    return NextResponse.json({ campaign });
  }
  return NextResponse.json({ error: 'Invalid type' }, { status: 400 });
}
