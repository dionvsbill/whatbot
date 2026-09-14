import { cookies } from 'next/headers';
import { verifySession } from '@/lib/security';
import { getOrCreateEarningProfile } from '@/lib/earnings';
import { db } from '@/lib/db';
import { money } from '@/lib/format';

export default async function EarnPage() {
  const userId = verifySession(cookies().get('whatbot_session')?.value);
  if (!userId) return <div className="rounded-2xl border bg-white p-6">Please sign in to view your earnings.</div>;
  const profile = await getOrCreateEarningProfile(userId);
  const [commissions, partners, campaigns] = await Promise.all([
    db.commission.findMany({ where: { earningProfileId: profile.id }, orderBy: { createdAt: 'desc' }, take: 8 }),
    db.affiliatePartner.findMany({ where: { userId }, include: { program: { include: { shop: true } } }, orderBy: { createdAt: 'desc' }, take: 8 }),
    db.creatorCampaign.findMany({ where: { status: 'ACTIVE' }, include: { shop: true }, orderBy: { createdAt: 'desc' }, take: 8 }),
  ]);
  const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
  const referralUrl = `${appUrl}/r/${profile.referralCode}`;
  return <div className="space-y-6">
    <div><h2 className="text-2xl font-bold">Earn with WhatBot</h2><p className="mt-1 text-sm text-slate-500">Earn from real referrals, merchant affiliate programs and creator campaigns.</p></div>
    <div className="grid gap-4 md:grid-cols-4">
      {[["Total earned", money(Number(profile.totalEarned))],["Pending", money(Number(profile.pendingBalance))],["Available", money(Number(profile.availableBalance))],["Conversions", String(profile.conversions) ]].map(([label,value])=><div className="rounded-2xl border bg-white p-5" key={label}><p className="text-sm text-slate-500">{label}</p><p className="mt-2 text-2xl font-bold">{value}</p></div>)}
    </div>
    <div className="grid gap-6 lg:grid-cols-2">
      <section className="rounded-2xl border bg-white p-6"><h3 className="font-bold">Your referral link</h3><p className="mt-2 break-all rounded-lg bg-slate-50 p-3 text-sm">{referralUrl}</p><p className="mt-3 text-sm text-slate-500">Code: <b>{profile.referralCode}</b> · {profile.clicks} clicks</p></section>
      <section className="rounded-2xl border bg-white p-6"><h3 className="font-bold">Withdraw earnings</h3><p className="mt-2 text-sm text-slate-500">Minimum payout: GHS 20. Payout requests are reviewed before transfer.</p><form action="/api/earn" method="post" className="mt-4 flex gap-2"><input type="hidden" name="action" value="payout"/><input name="amount" type="number" min="20" step="0.01" placeholder="Amount (GHS)" className="min-w-0 flex-1 rounded-lg border px-3 py-2"/><button className="rounded-lg bg-slate-950 px-4 py-2 font-semibold text-white">Request</button></form></section>
    </div>
    <section className="rounded-2xl border bg-white p-6"><h3 className="font-bold">Affiliate programs</h3>{partners.length ? <div className="mt-4 grid gap-3">{partners.map(p=><div className="flex items-center justify-between rounded-xl bg-slate-50 p-4" key={p.id}><div><b>{p.program.name}</b><p className="text-sm text-slate-500">{p.program.shop.name} · {p.status}</p></div><span className="font-semibold">{money(Number(p.earned))}</span></div>)}</div> : <p className="mt-3 text-sm text-slate-500">Join merchant programs to unlock product-based commissions.</p>}</section>
    <section className="rounded-2xl border bg-white p-6"><h3 className="font-bold">Creator campaigns</h3>{campaigns.length ? <div className="mt-4 grid gap-3">{campaigns.map(c=><div className="rounded-xl border p-4" key={c.id}><div className="flex items-center justify-between gap-4"><div><b>{c.title}</b><p className="text-sm text-slate-500">{c.shop.name}</p></div><span className="font-semibold">{money(Number(c.rewardPerCreator))}</span></div><p className="mt-2 text-sm text-slate-600">{c.description}</p></div>)}</div> : <p className="mt-3 text-sm text-slate-500">No active creator campaigns yet.</p>}</section>
    <section className="rounded-2xl border bg-white p-6"><h3 className="font-bold">Recent earnings</h3>{commissions.length ? <div className="mt-4 divide-y">{commissions.map(c=><div className="flex justify-between py-3" key={c.id}><span className="text-sm">{c.description || c.type}</span><span className="font-semibold">{money(Number(c.amount))} · {c.status}</span></div>)}</div> : <p className="mt-3 text-sm text-slate-500">Your earnings will appear here after a qualifying conversion.</p>}</section>
  </div>;
}
