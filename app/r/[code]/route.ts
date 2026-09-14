import { NextResponse } from 'next/server';
import { recordReferralClick } from '@/lib/earnings';

export async function GET(req: Request, { params }: { params: { code: string } }) {
  const url = new URL(req.url);
  const result = await recordReferralClick(params.code.toUpperCase(), {
    ip: req.headers.get('x-forwarded-for')?.split(',')[0]?.trim(),
    userAgent: req.headers.get('user-agent') || undefined,
    landingPath: url.searchParams.get('to') || '/',
  });
  if (!result) return NextResponse.redirect(new URL('/', url.origin));
  const destination = url.searchParams.get('to');
  const target = destination && destination.startsWith('/') && !destination.startsWith('//') ? destination : '/';
  const response = NextResponse.redirect(new URL(target, url.origin));
  response.cookies.set('whatbot_referral', params.code.toUpperCase(), { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', maxAge: 60 * 60 * 24 * 30, path: '/' });
  return response;
}
