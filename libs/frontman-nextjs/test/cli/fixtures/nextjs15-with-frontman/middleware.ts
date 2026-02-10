import { createMiddleware } from '@frontman-ai/nextjs';
import { NextRequest, NextResponse } from 'next/server';

const frontman = createMiddleware({
  host: 'old-server.company.com',
});

export async function middleware(req: NextRequest) {
  const response = await frontman(req);
  if (response) return response;
  return NextResponse.next();
}

export const config = {
  matcher: ['/frontman', '/frontman/:path*'],
};
