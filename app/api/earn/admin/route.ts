import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { db } from '@/lib/db';
import { verifySession } from '@/lib/security';

async function admin() {
  const userId = verifySession(cookies().get('whatbot_session')?.value);
  if (!userId) return null;
  const user = await db.user.findUnique({ where: { id: userId }, select: { role: true } });
  return user?.role === 'SUPER_ADMIN' ? userId : null;
}

export async function GET() {
  if (!await admin()) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  const [pending, payouts, stats] = await Promise.all([
    db.commission.findMany({ where: { status: 'PENDING' }, include: { earningProfile: { include: { user: { select: { id: true, name: true, email: true, phone: true } } } }, program: true }, orderBy: { createdAt: 'asc' }, take: 100 }),
    db.earningPayoutRequest.findMany({ where: { status: { in: ['REQUESTED', 'PROCESSING'] } }, include: { user: { select: { id: true, name: true, email: true, phone: true } } }, orderBy: { createdAt: 'asc' }, take: 100 }),
    db.commission.groupBy({ by: ['status'], _sum: { amount: true, platformFee: true }, _count: { id: true } }),
  ]);
  return NextResponse.json({ pending, payouts, stats });
}

export async function POST(req: Request) {
  if (!await admin()) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  const body = await req.json().catch(() => ({}));
  if (body.type === 'commission') {
    const id = String(body.id || '');
    const commission = await db.commission.findUnique({ where: { id } });
    if (!commission || commission.status !== 'PENDING') return NextResponse.json({ error: 'Commission unavailable' }, { status: 404 });
    const approved = await db.$transaction(async tx => {
      const c = await tx.commission.update({ where: { id }, data: { status: 'APPROVED', approvedAt: new Date() } });
      await tx.earningProfile.update({ where: { id: commission.earningProfileId }, data: { pendingBalance: { decrement: commission.amount }, availableBalance: { increment: commission.amount } } });
      return c;
    });
    return NextResponse.json({ commission: approved });
  }
  if (body.type === 'payout') {
    const id = String(body.id || '');
    const payout = await db.earningPayoutRequest.findUnique({ where: { id } });
    if (!payout || !['REQUESTED', 'PROCESSING'].includes(payout.status)) return NextResponse.json({ error: 'Payout unavailable' }, { status: 404 });
    if (body.status === 'REJECTED') {
      const result = await db.$transaction(async tx => {
        const p = await tx.earningPayoutRequest.update({ where: { id }, data: { status: 'REJECTED', processedAt: new Date(), note: String(body.note || 'Rejected').slice(0, 500) } });
        await tx.earningProfile.update({ where: { id: payout.earningProfileId }, data: { availableBalance: { increment: payout.amount } } });
        return p;
      });
      return NextResponse.json({ payout: result });
    }
    return NextResponse.json({ payout: await db.earningPayoutRequest.update({ where: { id }, data: { status: 'PROCESSING' } }) });
  }
  return NextResponse.json({ error: 'Invalid type' }, { status: 400 });
}
