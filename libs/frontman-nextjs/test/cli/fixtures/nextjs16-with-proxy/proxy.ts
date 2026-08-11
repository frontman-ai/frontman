import { NextRequest, NextResponse } from 'next/server';

export function proxy(req: NextRequest): NextResponse {
  if (req.nextUrl.pathname.startsWith('/api/external')) {
    return NextResponse.rewrite(new URL('https://external-api.com' + req.nextUrl.pathname));
  }
  return NextResponse.next();
}
