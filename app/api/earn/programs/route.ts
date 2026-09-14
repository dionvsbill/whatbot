import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { db } from '@/lib/db';
import { verifySession } from '@/lib/security';

export async function GET() {
  const programs = await db.affiliateProgram.findMany({ where: { status: 'ACTIVE' }, include: { shop: true, _count: { select: { partners: true } } }, orderBy: { createdAt: 'desc' }, take: 50 });
  return NextResponse.json({ programs });
}

export async function POST(req: Request) {
  const userId = verifySession(cookies().get('whatbot_session')?.value);
  if (!userId) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  const body = await req.json().catch(() => ({}));
  const program = await db.affiliateProgram.findUnique({ where: { id: String(body.programId || '') } });
  if (!program || program.status !== 'ACTIVE') return NextResponse.json({ error: 'Program unavailable' }, { status: 404 });
  const code = `${program.id.slice(-5).toUpperCase()}-${userId.slice(-7).toUpperCase()}`;
  const partner = await db.affiliatePartner.upsert({ where: { programId_userId: { programId: program.id, userId } }, update: {}, create: { programId: program.id, userId, code, status: 'ACTIVE' } });
  return NextResponse.json({ partner, link: `${process.env.NEXT_PUBLIC_APP_URL || ''}/r/${partner.code}` });
}
