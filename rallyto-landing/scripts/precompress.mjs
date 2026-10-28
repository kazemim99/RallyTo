// Writes a gzip (.gz) and a Brotli (.br) copy next to every text asset in dist/, at maximum compression, for
// nginx's gzip_static (built in) and brotli_static (only if the box has the module).
import { readdir, readFile, stat, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { brotliCompressSync, constants, gzipSync } from 'node:zlib'

const root = process.argv[2] ?? 'dist'
const TEXT = /\.(html|css|js|mjs|json|svg|xml|txt|webmanifest|woff2)$/i

async function* files(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) yield* files(path)
    else yield path
  }
}

let count = 0
for await (const path of files(root)) {
  if (!TEXT.test(path) || path.endsWith('.woff2')) continue // woff2 is already Brotli inside
  const body = await readFile(path)
  if ((await stat(path)).size < 256) continue
  await writeFile(`${path}.gz`, gzipSync(body, { level: 9 }))
  await writeFile(
    `${path}.br`,
    brotliCompressSync(body, { params: { [constants.BROTLI_PARAM_QUALITY]: 11 } }),
  )
  count++
}
console.log(`precompressed ${count} files in ${root}`)
