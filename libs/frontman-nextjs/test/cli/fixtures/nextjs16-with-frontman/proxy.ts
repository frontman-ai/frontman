import { createMiddleware } from '@frontman-ai/nextjs';
import { NextRequest, NextResponse } from 'next/server';

const frontman = createMiddleware({
  host: 'old-server.company.com',
});

export function proxy(req: NextRequest): NextResponse | Promise<NextResponse> {
  if (req.nextUrl.pathname === '/frontman' || req.nextUrl.pathname.startsWith('/frontman/')) {
    return frontman(req) || NextResponse.next();
  }
  return NextResponse.next();
}
