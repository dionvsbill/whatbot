import { NextRequest, NextResponse } from 'next/server';
import { verifySession } from './lib/security';

export function middleware(req: NextRequest) {
  const path = req.nextUrl.pathname;
  const response = path.startsWith('/dashboard') || path.startsWith('/admin')
    ? (() => {
        const id = verifySession(req.cookies.get('whatbot_session')?.value);
        return id ? NextResponse.next() : NextResponse.redirect(new URL('/login', req.url));
      })()
    : NextResponse.next();

  const isDev = process.env.NODE_ENV !== 'production';
  const csp = [
    "default-src 'self'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    "object-src 'none'",
    "img-src 'self' data: blob: https:",
    "font-src 'self' data: https:",
    "style-src 'self' 'unsafe-inline' https:",
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.paystack.co https://checkout.paystack.com" + (isDev ? " http://localhost:*" : ''),
    "connect-src 'self' https://*.supabase.co https://api.paystack.co https://*.paystack.co wss://*.supabase.co" + (isDev ? " ws://localhost:* http://localhost:*" : ''),
    "frame-src 'self' https://checkout.paystack.com https://*.paystack.co",
    "worker-src 'self' blob:",
  ].join('; ');

  response.headers.set('Content-Security-Policy', csp);
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  response.headers.set('Cross-Origin-Opener-Policy', 'same-origin-allow-popups');
  response.headers.set('Cross-Origin-Resource-Policy', 'same-site');
  if (!isDev) response.headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');

  return response;
}

export const config = { matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'] };
