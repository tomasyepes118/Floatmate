import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const files = execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'], {
  cwd: root, encoding: 'utf8',
}).split('\0').filter(Boolean);
const errors = [];
let htmlCount = 0;
let jsCount = 0;

for (const file of files) {
  const fullPath = path.join(root, file);
  if (!existsSync(fullPath)) {
    errors.push(`Archivo versionado ausente: ${file}`);
    continue;
  }
  if (/(^|\/)(node_modules|__pycache__|tmp|bin|obj|Herramientas_y_temporales)(\/|$)/i.test(file)
      || /\.(zip|nupkg|pem|key|pfx|p12)$/i.test(file)
      || /(^|\/)\.env($|\.)/.test(file) && !file.endsWith('.env.example')) {
    errors.push(`Archivo local o sensible incluido: ${file}`);
  }
  if (statSync(fullPath).size > 50 * 1024 * 1024) {
    errors.push(`Archivo mayor de 50 MiB: ${file}`);
  }
  if (/\.m?js$/i.test(file)) {
    jsCount++;
    const result = spawnSync(process.execPath, ['--check', fullPath], { encoding: 'utf8' });
    if (result.error || result.status !== 0) errors.push(`JavaScript inválido: ${file}\n${result.stderr || result.error}`);
  }
  // Los índices archivados conservan referencias históricas deliberadamente.
  if (!/\.html$/i.test(file) || file.startsWith('06_Material_adicional/Archivo/')) continue;
  htmlCount++;
  const html = readFileSync(fullPath, 'utf8');
  for (const match of html.matchAll(/\b(?:src|href)\s*=\s*["']([^"']+)["']/gi)) {
    const reference = match[1];
    if (/^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(reference)) continue;
    try {
      const relative = decodeURIComponent(reference.split(/[?#]/)[0]);
      if (relative && !existsSync(path.resolve(path.dirname(fullPath), relative))) {
        errors.push(`Referencia local ausente: ${file} -> ${reference}`);
      }
    } catch {
      errors.push(`Referencia local inválida: ${file} -> ${reference}`);
    }
  }
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exitCode = 1;
} else {
  console.log(`Correcto: ${files.length} archivos, ${htmlCount} HTML y ${jsCount} JavaScript comprobados.`);
}
