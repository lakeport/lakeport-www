/**
 * Minimal Cloudflare Worker edge host for `lakeport.dev`.
 *
 * - Redirects `www.lakeport.dev` and edge `http://lakeport.dev` requests to canonical `https://lakeport.dev`
 * - Serves `GET /api/capabilities` in `Site.Contract` wire format (`CAPS\t1\t...`)
 * - Delegates all pre-rendered SSG HTML, CSS, and Lean WebAssembly assets to `env.ASSETS`
 */

const HSTS = 'max-age=31536000; includeSubDomains; preload';
const CAPABILITY_ADVERTISEMENT = 'CAPS\t1\tlpw1,lpw2\tinstant_release,audit_receipt,batch_settle';

function applyEdgeHeaders(response, pathname, isHttpsProduction) {
  const headers = new Headers(response.headers);
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  headers.set('X-Frame-Options', 'SAMEORIGIN');
  if (isHttpsProduction) {
    headers.set('Strict-Transport-Security', HSTS);
  }

  if (pathname.endsWith('.wasm')) {
    headers.set('Content-Type', 'application/wasm');
    headers.set('Cache-Control', 'public, max-age=3600, stale-while-revalidate=86400');
  } else if (pathname.endsWith('.css') || pathname.endsWith('.mjs') || pathname.endsWith('.js') || pathname.endsWith('.svg')) {
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
    const isEdgeHttp = cfVisitor.includes('"scheme":"http"');
    const isHttpsProduction =
      url.protocol === 'https:' && (hostname === 'lakeport.dev' || hostname === 'www.lakeport.dev');

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
        isHttpsProduction
      );
    }

    const assetResponse = await env.ASSETS.fetch(request);
    return applyEdgeHeaders(assetResponse, url.pathname, isHttpsProduction);
  },
};
