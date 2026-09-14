import { createHash } from 'crypto';
import { db } from '@/lib/db';

export function makeReferralCode(userId: string) {
  return `WB-${createHash('sha256').update(`${userId}:${process.env.AUTH_SECRET || 'whatbot'}`).digest('hex').slice(0, 10).toUpperCase()}`;
}

export async function getOrCreateEarningProfile(userId: string) {
  const existing = await db.earningProfile.findUnique({ where: { userId } });
  if (existing) return existing;
  return db.earningProfile.create({ data: { userId, referralCode: makeReferralCode(userId) } });
}

export async function recordReferralClick(code: string, meta: { ip?: string; userAgent?: string; landingPath?: string } = {}) {
  const profile = await db.earningProfile.findUnique({ where: { referralCode: code } });
  const partner = await db.affiliatePartner.findUnique({ where: { code }, include: { program: true } });
  if (!profile && !partner) return null;
  const program = partner?.program && partner.program.status === 'ACTIVE' ? partner.program : null;
  await db.referralClick.create({
    data: {
      code,
      earningProfileId: profile?.id,
      partnerId: partner?.id,
      programId: program?.id,
      ipHash: meta.ip ? createHash('sha256').update(meta.ip).digest('hex') : undefined,
      userAgent: meta.userAgent?.slice(0, 500),
      landingPath: meta.landingPath?.slice(0, 500),
    },
  });
  if (profile) await db.earningProfile.update({ where: { id: profile.id }, data: { clicks: { increment: 1 } } });
  if (partner) await db.affiliatePartner.update({ where: { id: partner.id }, data: { clicks: { increment: 1 } } });
  return { profile, partner, program };
}

export async function attributePaidOrder(orderId: string, code: string) {
  const order = await db.order.findUnique({ where: { id: orderId } });
  if (!order || order.status === 'CANCELLED' || order.status === 'PENDING_PAYMENT') return null;
  if (await db.referralConversion.findUnique({ where: { orderId } })) return null;
  const profile = await db.earningProfile.findUnique({ where: { referralCode: code } });
  const partner = await db.affiliatePartner.findUnique({ where: { code } });
  const program = partner ? await db.affiliateProgram.findUnique({ where: { id: partner.programId } }) : null;
  const earner = profile ?? (partner ? await getOrCreateEarningProfile(partner.userId) : null);
  if (!earner || (!profile && (!program || program.status !== 'ACTIVE'))) return null;
  if (profile && order.customerId === profile.userId) return null;
  const value = Number(order.total);
  const gross = program ? (program.fixedReward != null ? Number(program.fixedReward) : value * (program.commissionRate / 100)) : Math.min(value * 0.05, 50);
  const reward = program?.maxReward != null ? Math.min(gross, Number(program.maxReward)) : gross;
  if (reward <= 0) return null;
  const platformFee = reward * 0.1;
  const cashback = program ? reward * (program.cashbackRate / 100) : 0;
  const amount = Math.max(0, reward - platformFee - cashback);
  return db.$transaction(async (tx) => {
    const conversion = await tx.referralConversion.create({ data: { orderId, partnerId: partner?.id, programId: program?.id, code, orderValue: value } });
    const commission = await tx.commission.create({ data: { earningProfileId: earner.id, partnerId: partner?.id, programId: program?.id, conversionId: conversion.id, type: program ? 'AFFILIATE' : 'REFERRAL', amount, platformFee, cashback, description: `Reward for order ${order.orderNumber}` } });
    await tx.earningProfile.update({ where: { id: earner.id }, data: { totalEarned: { increment: amount }, pendingBalance: { increment: amount }, conversions: { increment: 1 } } });
    if (partner) await tx.affiliatePartner.update({ where: { id: partner.id }, data: { earned: { increment: amount }, conversions: { increment: 1 } } });
    await tx.earningEvent.create({ data: { userId: earner.userId, type: 'PURCHASE', referenceId: order.id, metadata: { code, amount } } });
    return { conversion, commission };
  });
}
