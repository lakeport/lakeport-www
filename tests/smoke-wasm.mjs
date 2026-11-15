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
assert.ok(allText().includes('$100.00 / $100.00'));

// 2. Reserve $25 -> Drop socket -> Inject unnegotiated v2 frame
clickByLabel('Reserve $25.00');
assert.ok(allText().includes('$75.00'));
assert.ok(allText().includes('$25.00'));

clickByLabel('Drop socket');
assert.ok(allText().includes('Uncertain: cid-1 (locked until sync)'));

clickByLabel('Inject unnegotiated v2 frame');
assert.ok(allText().includes('permitsEncodedFrame rejected unnegotiated v2 frame before socket write'));

// 3. Patch B counterexample in live Wasm
clickByLabel('Patch B: Agent naive retry fix');
clickByLabel('Run counterexample in live ledger');
assert.ok(allText().includes('INVARIANT VIOLATED (Patch B)'));
assert.ok(allText().includes('$75.00 / $100.00'));

// 4. Live MDX Sandbox on /ecosystem
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

// 5. Embedded <ContractSimulator /> inside /docs/versioned-contracts
session.navigate('/docs/versioned-contracts');
clickByLabel('Corrupt CAPS schema v99');
assert.ok(allText().includes('none (fail-closed: unknown schema rejected)'));

session.dispose();
console.log('PASS: Interactive Wasm smoke suite verified Workbench, Gate, Counterexample, Live MDX Sandbox, and Docs Simulator.');
