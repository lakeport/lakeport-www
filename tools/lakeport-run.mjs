#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');

function resolveLakeportBin() {
  if (process.env.LAKEPORT_BIN && fs.existsSync(process.env.LAKEPORT_BIN)) {
    return process.env.LAKEPORT_BIN;
  }
  const pathDirs = (process.env.PATH ?? '').split(path.delimiter);
  for (const dir of pathDirs) {
    if (!dir) continue;
    const cand = path.join(dir, 'lakeport');
    if (fs.existsSync(cand)) return cand;
  }
  const siblingCandidates = [
    path.resolve(repoRoot, '../lakeport/packages/lakeport-cli/bin/lakeport'),
    path.join(os.homedir(), '.lakeport', 'bin', 'lakeport'),
  ];
  for (const cand of siblingCandidates) {
    if (fs.existsSync(cand)) return cand;
  }
  console.error('Could not find `lakeport` on PATH or in LAKEPORT_BIN.');
  process.exit(1);
}

const args = process.argv.slice(2);
const env = { ...process.env };
if (!env.TMPDIR || env.TMPDIR.startsWith('/dev/shm')) {
  const cacheTmp = path.join(os.homedir(), '.cache', 'lakeport', 'tasks', 'lakeport-www', 'tmp');
  fs.mkdirSync(cacheTmp, { recursive: true });
  env.TMPDIR = cacheTmp;
}
if (!env.LAKEPORT_TASK_DIR) {
  const cliDir = path.join(os.homedir(), '.cache', 'lakeport', 'tasks', 'lakeport-www', 'cli');
  fs.mkdirSync(cliDir, { recursive: true });
  env.LAKEPORT_TASK_DIR = cliDir;
}

const bin = resolveLakeportBin();
const res = spawnSync(bin, args, { cwd: repoRoot, env, stdio: 'inherit' });
process.exit(res.status ?? 1);
