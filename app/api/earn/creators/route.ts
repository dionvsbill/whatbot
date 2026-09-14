import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { db } from '@/lib/db';
import { verifySession } from '@/lib/security';

export async function GET() {
  const campaigns = await db.creatorCampaign.findMany({ where: { status: 'ACTIVE' }, include: { shop: true, _count: { select: { applications: true } } }, orderBy: { createdAt: 'desc' }, take: 50 });
  return NextResponse.json({ campaigns });
}

export async function POST(req: Request) {
  const userId = verifySession(cookies().get('whatbot_session')?.value);
  if (!userId) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  const body = await req.json().catch(() => ({}));
  const campaignId = String(body.campaignId || '');
  const campaign = await db.creatorCampaign.findUnique({ where: { id: campaignId }, include: { _count: { select: { applications: true } } } });
  if (!campaign || campaign.status !== 'ACTIVE') return NextResponse.json({ error: 'Campaign unavailable' }, { status: 404 });
  if (campaign._count.applications >= campaign.maxCreators) return NextResponse.json({ error: 'Campaign is full' }, { status: 409 });
  const application = await db.creatorApplication.upsert({ where: { campaignId_creatorId: { campaignId, creatorId: userId } }, update: { note: body.note ? String(body.note).slice(0, 1000) : undefined }, create: { campaignId, creatorId: userId, note: body.note ? String(body.note).slice(0, 1000) : undefined } });
  return NextResponse.json({ application });
}
