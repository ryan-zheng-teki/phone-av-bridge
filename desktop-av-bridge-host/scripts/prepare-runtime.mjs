import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');

async function main() {
  const sourceNodeBinary = process.execPath;
  const sourceNodeBinDir = path.dirname(sourceNodeBinary);
  const sourceNodePrefix = path.resolve(sourceNodeBinDir, '..');
  const sourceNodeLibDir = path.join(sourceNodePrefix, 'lib');

  const runtimeRoot = path.join(projectRoot, 'runtime', 'node');
  const runtimeBinDir = path.join(projectRoot, 'runtime', 'node', 'bin');
  const targetNodeBinary = path.join(runtimeBinDir, 'node');
  const targetNodeLibDir = path.join(runtimeRoot, 'lib');

  await fs.rm(runtimeRoot, { recursive: true, force: true });
  await fs.mkdir(runtimeBinDir, { recursive: true });
  await fs.copyFile(sourceNodeBinary, targetNodeBinary);
  await fs.chmod(targetNodeBinary, 0o755);

  // Homebrew/macOS and many Linux distros ship node with a sibling lib directory.
  // Copy only Node runtime libraries (libnode*) to avoid pulling the entire system lib tree.
  try {
    await fs.access(sourceNodeLibDir);
    const entries = await fs.readdir(sourceNodeLibDir, { withFileTypes: true });
    const runtimeLibEntries = entries.filter((entry) => entry.name.startsWith('libnode'));
    if (runtimeLibEntries.length > 0) {
      await fs.mkdir(targetNodeLibDir, { recursive: true });
      for (const entry of runtimeLibEntries) {
        const sourcePath = path.join(sourceNodeLibDir, entry.name);
        const targetPath = path.join(targetNodeLibDir, entry.name);
        await fs.cp(sourcePath, targetPath, { recursive: true, dereference: true });
      }
    }
  } catch {
    // If no lib directory exists for this runtime layout, continue with node binary only.
  }

  console.log(`bundled runtime prepared: ${targetNodeBinary}`);
  console.log(`runtime root: ${runtimeRoot}`);
  console.log(`source node binary: ${sourceNodeBinary}`);
}

main().catch((error) => {
  console.error(`failed to prepare runtime bundle: ${error.message}`);
  process.exit(1);
});
