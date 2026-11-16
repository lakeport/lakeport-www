#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const distWeb = path.resolve(__dirname, '../dist/web');

const { loadLp2 } = await import(path.join(distWeb, 'runtime/lp2-abi.mjs'));
const { LakeportSession } = await import(path.join(distWeb, 'runtime/boot.mjs'));
const factoryMod = await import(path.join(distWeb, 'wasm/app_lp2.js'));
const createModule = factoryMod.default ?? factoryMod;
const wasmBinary = fs.readFileSync(path.join(distWeb, 'wasm/app_lp2.wasm'));

const client = await loadLp2(opts => createModule({ ...opts, wasmBinary }));
const session = new LakeportSession({
  client,
  config: { caps: { publicCap: 524288, heldCap: 262144 } },
  schedule: () => 0,
});

const allText = () =>
  [...session.mirror.nodes.values()]
    .filter(n => n.type === 'text')
    .map(n => n.value)
    .join('\n');

const clickByLabel = label => {
  const btn = session.mirror.findButton(label);
  assert.ok(btn, `Expected button "${label}" to exist`);
  const res = session.press(btn.id);
  assert.equal(res.class, 'installed', `Expected press("${label}") to install`);
};

// 1. Boot homepage: customer wallet starts at $100.00, $0.00 charged
const bootRes = session.start();
assert.equal(bootRes.class, 'installed');
assert.ok(allText().includes('$100.00'));
assert.ok(allText().includes('$0.00'));
assert.ok(session.mirror.findButton("1. Agent's first draft (tests pass)"));

// 2. Run normal Wi-Fi test on Agent's first draft: unit test passes ($75.00 left, $25.00 charged)
clickByLabel('Pay $25 on normal Wi-Fi');
assert.ok(allText().includes('$75.00'));
assert.ok(allText().includes('$25.00'));
assert.ok(allText().includes('Unit test passed'));

// 3. Run flaky Wi-Fi on Agent's first draft: double-charges $50.00 ($50.00 left!)
clickByLabel('Pay $25 on flaky Wi-Fi');
assert.ok(allText().includes('$50.00'));
assert.ok(allText().includes('Billed twice for one item'));

// 4. Switch in one click to Lakeport's checked fix on flaky Wi-Fi: charges $25.00 once ($75.00 left)
clickByLabel("See Lakeport's checked fix on flaky Wi-Fi →");
assert.ok(allText().includes('$75.00'));
assert.ok(allText().includes('$25.00'));
assert.ok(allText().includes('Billed once as expected'));

// 5. Open optional Lean rule disclosure
clickByLabel('Curious what the proof looks like? Show the rule the agent wrote');
assert.ok(allText().includes('lakeportFixed_never_overcharges'));

// 6. Live MDX Sandbox on /ecosystem
session.navigate('/ecosystem');
const mdxInput = [...session.mirror.nodes.values()].find(
  n => n.type === 'input' && n.label === 'MDX sandbox source'
);
assert.ok(mdxInput, 'Expected MDX sandbox textarea on /ecosystem');
session.input(
  mdxInput.id,
  '## Custom interactive heading\n\nRendered by **pure Lean Wasm** on keystroke.'
);
assert.ok(allText().includes('Custom interactive heading'));
assert.ok(allText().includes('pure Lean Wasm'));

// 7. Embedded <ContractSimulator /> inside /docs/versioned-contracts (real LakeportJson union + headers)
session.navigate('/docs/versioned-contracts');
assert.ok(allText().includes('OrderSchema.v1 (matched from JSON shape alone, no version header needed)'));
clickByLabel('2. Backend v2 JSON (no header)');
assert.ok(allText().includes('OrderSchema.v2 (matched from nested amount JSON without a capability endpoint)'));
clickByLabel('3. Backend v2 + capability header');
assert.ok(allText().includes('Shown: POST /api/orders/ord-42/refund enabled by v2 schema + header'));
clickByLabel('4. Unexpected v99 JSON');
assert.ok(allText().includes('none (fail-closed: unknown schema rejected cleanly)'));

// 8. Section 4 ("How Lakeport is built") diagrams & contributor guide
session.navigate('/docs/architecture-overview');
assert.ok(allText().includes('Lakeport 4-Tier Architecture Stack'));
session.navigate('/docs/compiler-and-runtime');
assert.ok(allText().includes('Compiler & WebAssembly Release Pipeline'));
assert.ok(allText().includes('Single-Frame LP2 v4 Dispatch & Two-Phase Command Cycle'));
session.navigate('/docs/contributor-guide');
assert.ok(allText().includes('is the code actually good, or is it just working?'));

session.dispose();
console.log('PASS: Interactive Wasm smoke suite verified Checkout Simulator, JSON Schema Simulator, Live MDX, and Section 4 Architecture Diagrams.');
