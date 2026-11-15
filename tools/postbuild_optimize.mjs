#!/usr/bin/env node
/**
 * Post-build runtime a11y/perf patcher & esbuild asset minifier for `dist/web`.
 *
 * 1. Yields to the browser event loop between `factory()`, `session.start()`,
 *    `session.navigate()`, and `session.attachRenderer()` inside `boot.mjs#mount`
 *    so Wasm hydration slices stay below 50ms on throttled mobile CPUs.
 * 2. Marks dynamic decorative `<svg data-lp-svg>` elements `aria-hidden="true"`
 *    (Safari Web Inspector Audit) and horizontal scroll containers `tabindex="0"`
 *    (Firefox/axe `scrollable-region-focusable`) in `dom-renderer.mjs`.
 * 3. Minifies `dist/web/runtime/*.mjs`, `dist/web/assets/entry.mjs`,
 *    `dist/web/wasm/app_lp2.js`, and `dist/web/bundle.css` + updates `.gz` files.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import esbuild from 'esbuild';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const distWeb = path.resolve(__dirname, '../dist/web');

function writeWithGz(filePath, content) {
  const buf = Buffer.from(content, 'utf8');
  fs.writeFileSync(filePath, buf);
  const gzPath = `${filePath}.gz`;
  if (fs.existsSync(gzPath)) {
    fs.writeFileSync(gzPath, zlib.gzipSync(buf, { level: 9 }));
  }
}

// 1. Patch boot.mjs mount() with micro-yields between phases
const bootPath = path.join(distWeb, 'runtime/boot.mjs');
if (fs.existsSync(bootPath)) {
  let bootSrc = fs.readFileSync(bootPath, 'utf8');
  const bootTarget = '    await session.loadConfiguredPlugins();\n    const r = session.start();';
  const bootReplace =
    '    const lpYield = () => new Promise(res => setTimeout(res, 0));\n' +
    '    await session.loadConfiguredPlugins();\n' +
    '    await lpYield();\n' +
    '    const r = session.start();';
  if (bootSrc.includes(bootTarget)) {
    bootSrc = bootSrc.replace(bootTarget, bootReplace);
    bootSrc = bootSrc.replace(
      '        try { session.navigate(initUrl); } finally { syncingPop = false; }\n      }\n    }\n    if (ssgRoute !== null) {',
      '        try { session.navigate(initUrl); } finally { syncingPop = false; }\n        await lpYield();\n      }\n    }\n    if (ssgRoute !== null) {\n      await lpYield();'
    );
    fs.writeFileSync(bootPath, bootSrc, 'utf8');
  }
}

// 2. Patch dom-renderer.mjs for decorative SVG aria-hidden + scrollable tabindex="0"
const domPath = path.join(distWeb, 'runtime/dom-renderer.mjs');
if (fs.existsSync(domPath)) {
  let domSrc = fs.readFileSync(domPath, 'utf8');
  const clsTarget = "      if (cls) el.setAttribute('class', cls); else el.removeAttribute('class');\n    }";
  const clsReplace =
    "      if (cls) el.setAttribute('class', cls); else el.removeAttribute('class');\n" +
    "      if (/(?:codePre|tableWrap|wb-code-body)/.test(cls)) el.setAttribute('tabindex', '0');\n" +
    "      if (cls === 'docs-sidebar') el.setAttribute('aria-label', 'Chapters');\n" +
    "      else if (cls === 'docs-toc') el.setAttribute('aria-label', 'On this page');\n" +
    "      else if (cls === 'waterline-reflection-text') el.setAttribute('aria-hidden', 'true');\n" +
    '    }';
  if (domSrc.includes(clsTarget)) {
    domSrc = domSrc.replace(clsTarget, clsReplace);
  }

  const svgTarget = "    for (const [a, v] of want) if (el.getAttribute(a) !== v) el.setAttribute(a, v);\n    n.ownedSvg = new Set(want.keys());";
  const svgReplace =
    "    for (const [a, v] of want) if (el.getAttribute(a) !== v) el.setAttribute(a, v);\n" +
    "    if (n.tag === 'svg' && !el.hasAttribute('aria-label')) {\n" +
    "      if (el.getAttribute('aria-hidden') !== 'true') el.setAttribute('aria-hidden', 'true');\n" +
    "      if (el.getAttribute('focusable') !== 'false') el.setAttribute('focusable', 'false');\n" +
    "    }\n" +
    "    n.ownedSvg = new Set(want.keys());";
  if (domSrc.includes(svgTarget)) {
    domSrc = domSrc.replace(svgTarget, svgReplace);
  }
  fs.writeFileSync(domPath, domSrc, 'utf8');
}

// 3. Minify JS/MJS and CSS bundles in dist/web
const jsTargets = [];
const runtimeDir = path.join(distWeb, 'runtime');
if (fs.existsSync(runtimeDir)) {
  for (const name of fs.readdirSync(runtimeDir)) {
    if (name.endsWith('.mjs') || name.endsWith('.js')) {
      jsTargets.push(path.join(runtimeDir, name));
    }
  }
}
for (const extra of ['assets/entry.mjs', 'wasm/app_lp2.js']) {
  const full = path.join(distWeb, extra);
  if (fs.existsSync(full)) jsTargets.push(full);
}

let savedBytes = 0;
for (const file of jsTargets) {
  const raw = fs.readFileSync(file, 'utf8');
  const out = await esbuild.transform(raw, {
    loader: 'js',
    minify: true,
    target: 'es2022',
    legalComments: 'none',
  });
  savedBytes += Buffer.byteLength(raw) - Buffer.byteLength(out.code);
  writeWithGz(file, out.code);
}

const cssPath = path.join(distWeb, 'bundle.css');
if (fs.existsSync(cssPath)) {
  const rawCss = fs.readFileSync(cssPath, 'utf8');
  const outCss = await esbuild.transform(rawCss, {
    loader: 'css',
    minify: true,
    legalComments: 'none',
  });
  savedBytes += Buffer.byteLength(rawCss) - Buffer.byteLength(outCss.code);
  writeWithGz(cssPath, outCss.code);
}

console.log(`[postbuild_optimize] Patched runtime a11y/yields and minified ${jsTargets.length + 1} bundles (saved ${(savedBytes / 1024).toFixed(1)} KB).`);
