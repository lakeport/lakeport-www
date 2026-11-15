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

// 1. Boot homepage
const bootRes = session.start();
assert.equal(bootRes.class, 'installed');
assert.ok(allText().includes('$100.00'));
assert.ok(allText().includes('of $100.00 conserved'));

// 2. Run faulty agent retry counterexample in live Wasm
clickByLabel('Run faulty retry');
assert.ok(allText().includes('$75.00'));
assert.ok(allText().includes('of $100.00 · $25.00 missing'));
assert.ok(allText().includes('LedgerConserved ($100.00 → $75.00 after socket retry)'));

// 3. Compare checked reducer (locks cid-1 as .uncertain and blocks duplicate retry)
clickByLabel('Compare checked reducer');
assert.ok(allText().includes('$100.00'));
assert.ok(allText().includes('delivery: .uncertain (cid-1 locked)'));
assert.ok(allText().includes('Duplicate retry rejected while cid-1 awaits reconciliation'));

// 4. Open wire & capability gate disclosure and inject unnegotiated v2 frame
clickByLabel('+ Explore wire & capability gates');
clickByLabel('Inject unnegotiated v2 frame');
assert.ok(allText().includes('permitsEncodedFrame rejected unnegotiated v2 frame before socket write'));

// 5. Live MDX Sandbox on /ecosystem
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

// 6. Embedded <ContractSimulator /> inside /docs/versioned-contracts
session.navigate('/docs/versioned-contracts');
clickByLabel('Corrupt CAPS schema v99');
assert.ok(allText().includes('none (fail-closed: unknown schema rejected)'));

session.dispose();
console.log('PASS: Interactive Wasm smoke suite verified Waterline Workbench, Checked Comparison, Capability Gate, Live MDX, and Docs Simulator.');
