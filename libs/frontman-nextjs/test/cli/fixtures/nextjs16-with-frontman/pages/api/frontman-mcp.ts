import { timingSafeEqual } from 'node:crypto';
import { createMcpHandler } from '@frontman-ai/nextjs';

const token = process.env.FRONTMAN_MCP_TOKEN;
const allowedOrigins = process.env.FRONTMAN_MCP_ALLOWED_ORIGINS
  ?.split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

if (!token) throw new Error('FRONTMAN_MCP_TOKEN is required');
if (!allowedOrigins?.length) throw new Error('FRONTMAN_MCP_ALLOWED_ORIGINS is required');

const cookieName = 'frontman_mcp_session';
const expectedCookie = Buffer.from(encodeURIComponent(token));
const expectedAuthorization = Buffer.from(`Bearer ${token}`);
const matches = (supplied: Buffer, expected: Buffer) =>
  supplied.length === expected.length && timingSafeEqual(supplied, expected);
const credentials = (headers: Headers) => {
  const cookieValues = (headers.get('Cookie') ?? '')
    .split(';')
    .map((part) => part.trim())
    .flatMap((part) => {
      const separator = part.indexOf('=');
      return separator >= 0 && part.slice(0, separator) === cookieName
        ? [part.slice(separator + 1)]
        : [];
    });
  const authorization = headers.get('Authorization');
  const cookieMatches = cookieValues.length === 1
    && matches(Buffer.from(cookieValues[0]), expectedCookie);
  const authorizationMatches = authorization
    ? matches(Buffer.from(authorization), expectedAuthorization)
    : false;
  return { authorization, authorizationMatches, cookieMatches, cookieValues };
};

const handler = createMcpHandler({
  mcp: {
    allowedOrigins,
    authorize: async (headers) => {
      const { authorization, authorizationMatches, cookieMatches, cookieValues } = credentials(headers);
      if (cookieValues.length === 0 && !authorization) return 'missing-authentication';
      if (cookieValues.length > 1) return 'insufficient-authorization';
      return cookieMatches || authorizationMatches
        ? 'authorized'
        : 'insufficient-authorization';
    },
    principal: (headers) => credentials(headers).cookieMatches
      ? 'configured-browser-cookie'
      : 'configured-bearer-token',
  },
});

export default handler;

export const config = {
  api: { bodyParser: false },
};
