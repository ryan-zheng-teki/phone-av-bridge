import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const execFileAsync = promisify(execFile);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');
const distDir = path.join(projectRoot, 'dist');

async function build() {
  await fs.mkdir(distDir, { recursive: true });
  await execFileAsync('node', [path.join(projectRoot, 'scripts', 'prepare-runtime.mjs')], {
    cwd: projectRoot,
  });

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const archiveName = `host-resource-agent-${process.platform}-${stamp}.tar.gz`;
  const archivePath = path.join(distDir, archiveName);

  await execFileAsync('tar', [
    '-czf',
    archivePath,
    '-C',
    projectRoot,
    'package.json',
    'README.md',
    'core',
    'adapters',
    'linux-app',
    'installers',
    'scripts',
    'runtime',
  ]);

  console.log(`release archive created: ${archivePath}`);
}

build().catch((error) => {
  console.error(`failed to build release: ${error.message}`);
  process.exit(1);
});
