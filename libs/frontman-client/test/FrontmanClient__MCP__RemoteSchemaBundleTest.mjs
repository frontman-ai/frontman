import {mkdtemp, readFile, readdir, rm, writeFile} from 'node:fs/promises'
import {tmpdir} from 'node:os'
import {join, resolve} from 'node:path'
import {build} from 'vite'

export const buildWorkerConsumer = async () => {
  const root = await mkdtemp(join(tmpdir(), 'frontman-schema-worker-'))
  try {
    const entry = join(root, 'entry.mjs')
    const modulePath = resolve('src/FrontmanClient__MCP__RemoteSchema.res.mjs')
    await writeFile(entry, `import {compileSchema} from ${JSON.stringify(modulePath)}\nexport {compileSchema}\n`)
    await build({
      configFile: false,
      logLevel: 'silent',
      build: {
        lib: {entry, formats: ['es'], fileName: 'client'},
        outDir: join(root, 'dist'),
        emptyOutDir: true,
      },
    })
    const files = await readdir(join(root, 'dist'))
    const assetFiles = await readdir(join(root, 'dist', 'assets'))
    const workerFile = assetFiles.find(file => file.endsWith('.js'))
    if (workerFile === undefined) {
      throw new Error(`Worker chunk missing from browser bundle: ${assetFiles.join(', ')}`)
    }
    const worker = await readFile(join(root, 'dist', 'assets', workerFile), 'utf8')
    return {files: [...files, ...assetFiles], worker}
  } finally {
    await rm(root, {recursive: true, force: true})
  }
}
