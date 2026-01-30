import { NextRequest, NextResponse } from 'next/server';

export function middleware(req: NextRequest) {
  // Custom authentication middleware
  const token = req.cookies.get('token');
  if (!token) {
    return NextResponse.redirect(new URL('/login', req.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*'],
};
