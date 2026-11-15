/**
 * Cloudflare Worker edge host for `lakeport.dev`.
 *
 * - Redirects `www.lakeport.dev` and edge `http://lakeport.dev` requests to canonical `https://lakeport.dev`
 * - Serves `GET /api/capabilities` in `Site.Contract` wire format (`CAPS\t1\t...`)
 * - Serves host-aware `/.well-known/ard.json` and `/robots.txt` for SEO & Agentic Resource Discovery
 * - Maps `/favicon.ico` and `/favicon.svg` to `/assets/brand/*`
 * - Applies strict CSP (no `'unsafe-inline'`), HSTS, COOP, CORP, Permissions-Policy, and asset caching
 */

const HSTS = 'max-age=31536000; includeSubDomains; preload';
const CSP = [
  "default-src 'none'",
  "script-src 'self' 'wasm-unsafe-eval'",
  "style-src 'self'",
  "img-src 'self' data:",
  "font-src 'self'",
  "connect-src 'self'",
  "manifest-src 'self'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
  "object-src 'none'",
].join('; ');
const PERMISSIONS_POLICY =
  'accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()';
const CAPABILITY_ADVERTISEMENT = 'CAPS\t1\tlpw1,lpw2\tinstant_release,audit_receipt,batch_settle';

function buildArdManifest(publisher, externalOrigin) {
  return JSON.stringify(
    {
      entries: [
        {
          identifier: `urn:air:${publisher}:docs:skills`,
          displayName: 'Lakeport Documentation and Agent Guide',
          description:
            'Documentation for .lp JSX-style views, CSS styling, plain-English business rules, versioned client API contracts, and the lakeport mcp compiler tool server.',
          type: 'text/markdown; profile="urn:air:agent-skills"',
          url: `${externalOrigin}/llms.txt`,
          representativeQueries: [
            'How do I build a Lakeport web app with an AI coding agent?',
            'How does lakeport mcp give coding agents structured compiler feedback?',
            'How do versioned client contracts keep older browser tabs working during backend deploys?',
          ],
        },
      ],
    },
    null,
    2
  );
}

function applyEdgeHeaders(response, pathname, isHttps) {
  const headers = new Headers(response.headers);
  headers.set('Content-Security-Policy', CSP);
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  headers.set('X-Frame-Options', 'DENY');
  headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
  headers.set('Cross-Origin-Resource-Policy', 'same-origin');
  headers.set('Permissions-Policy', PERMISSIONS_POLICY);
  if (isHttps) {
    headers.set('Strict-Transport-Security', HSTS);
  }

  if (pathname.endsWith('.wasm')) {
    headers.set('Content-Type', 'application/wasm');
    headers.set('Cache-Control', 'public, max-age=604800, stale-while-revalidate=86400');
  } else if (pathname.endsWith('.woff2')) {
    headers.set('Content-Type', 'font/woff2');
    headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  } else if (
    pathname.endsWith('.css') ||
    pathname.endsWith('.mjs') ||
    pathname.endsWith('.js') ||
    pathname.endsWith('.svg') ||
    pathname.endsWith('.ico') ||
    pathname.endsWith('.png')
  ) {
    headers.set('Cache-Control', 'public, max-age=604800, stale-while-revalidate=86400');
  } else if (pathname === '/llms.txt') {
    headers.set('Content-Type', 'text/markdown; charset=utf-8');
    headers.set('Cache-Control', 'public, max-age=3600, stale-while-revalidate=86400');
  } else if (!headers.has('Cache-Control')) {
    headers.set('Cache-Control', 'public, max-age=300, stale-while-revalidate=86400');
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const hostname = url.hostname.toLowerCase();
    const cfVisitor = request.headers.get('cf-visitor') || '';
    const xProto = (request.headers.get('x-forwarded-proto') || '').toLowerCase();
    const isEdgeHttp = cfVisitor.includes('"scheme":"http"');
    const isHttps = url.protocol === 'https:' || xProto === 'https' || cfVisitor.includes('"scheme":"https"');

    if (hostname === 'www.lakeport.dev' || (hostname === 'lakeport.dev' && isEdgeHttp)) {
      return new Response(null, {
        status: 301,
        headers: {
          Location: `https://lakeport.dev${url.pathname}${url.search}`,
          'Strict-Transport-Security': HSTS,
        },
      });
    }

    if (url.pathname === '/api/capabilities') {
      if (request.method !== 'GET' && request.method !== 'HEAD') {
        return new Response('Method Not Allowed', { status: 405, headers: { Allow: 'GET, HEAD' } });
      }
      return applyEdgeHeaders(
        new Response(request.method === 'HEAD' ? null : CAPABILITY_ADVERTISEMENT, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'no-store',
          },
        }),
        url.pathname,
        isHttps
      );
    }

    if (url.pathname === '/.well-known/ard.json') {
      if (request.method !== 'GET' && request.method !== 'HEAD') {
        return new Response('Method Not Allowed', { status: 405, headers: { Allow: 'GET, HEAD' } });
      }
      const rawHost = request.headers.get('x-forwarded-host') || request.headers.get('host') || url.host;
      const publisher = rawHost.split(':')[0].toLowerCase();
      const externalOrigin = `${isHttps ? 'https' : 'http'}://${rawHost}`;
      return applyEdgeHeaders(
        new Response(request.method === 'HEAD' ? null : buildArdManifest(publisher, externalOrigin), {
          status: 200,
          headers: {
            'Content-Type': 'application/ai-catalog+json; charset=utf-8',
            'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400',
          },
        }),
        url.pathname,
        isHttps
      );
    }

    if (url.pathname === '/robots.txt') {
      const rawHost = request.headers.get('x-forwarded-host') || request.headers.get('host') || url.host;
      const originStr = `${isHttps ? 'https' : 'http'}://${rawHost}`;
      const robotsTxt = `User-agent: *\nAllow: /\n\nSitemap: ${originStr}/sitemap.xml\n`;
      return applyEdgeHeaders(
        new Response(request.method === 'HEAD' ? null : robotsTxt, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400',
          },
        }),
        url.pathname,
        isHttps
      );
    }

    if (url.pathname === '/favicon.ico' || url.pathname === '/favicon.svg') {
      const targetUrl = new URL(`/assets/brand${url.pathname}`, url.origin);
      const rewritten = new Request(targetUrl.toString(), request);
      const assetRes = await env.ASSETS.fetch(rewritten);
      return applyEdgeHeaders(assetRes, targetUrl.pathname, isHttps);
    }

    const assetResponse = await env.ASSETS.fetch(request);
    return applyEdgeHeaders(assetResponse, url.pathname, isHttps);
  },
};
