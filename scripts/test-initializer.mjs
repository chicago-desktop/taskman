import { cp, mkdtemp, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { initialize } from './init-module.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

// The initializer can only be exercised from the pristine template: an
// initialized checkout no longer contains the chicago/module-template
// placeholders the test rewrites. Module checkouts skip this suite; the
// template repository's CI still runs it on every change.
const rootConfig = JSON.parse(await readFile(resolve(root, '.kickside-module.json'), 'utf8'))
if (rootConfig.initialized) {
  console.log('Initializer test skipped: checkout is already initialized; the suite runs in the template repository CI.')
  process.exit(0)
}

const target = await mkdtemp(resolve(tmpdir(), 'chicago-module-init-'))

await cp(root, target, {
  recursive: true,
  filter: (source) => !['.git', '.wippy', '.local', 'node_modules', 'shots'].some((name) => source.split(/[\\/]/).includes(name)),
})

const args = [
  '--organization', 'orbit', '--module', 'tasks', '--title', 'Orbit Tasks',
  '--namespace', 'orbit.work.tasks', '--tag', 'orbit-tasks', '--github-owner', 'orbit-dev']
await initialize(args, target)

const read = (path) => readFile(resolve(target, path), 'utf8')
const config = JSON.parse(await read('.kickside-module.json'))
if (!config.initialized || config.identity.namespace !== 'orbit.work.tasks') throw new Error('initializer did not record the requested identity')
const manifest = await read('wippy.yaml')
const index = await read('src/_index.yaml')
const harness = await read('test/wippy.yaml')
const harnessConfig = await read('test/.wippy.yaml')
const harnessIndex = await read('test/src/_index.yaml')
const makefile = await read('Makefile')
const readme = await read('README.md')
if (!manifest.includes('organization: orbit') || !manifest.includes('module: tasks')) throw new Error('initializer did not update package identity')
if (!manifest.includes('https://github.com/orbit-dev/tasks')) throw new Error('initializer did not update the repository URL')
if (!manifest.includes('- orbit.work.tasks:images')) throw new Error('initializer did not update the embed list')
if (!index.includes('namespace: orbit.work.tasks') || !index.includes('title: Orbit Tasks')) throw new Error('initializer did not update registry identity')
if (!index.includes('group: Programs/Orbit Tasks') || !index.includes('image: orbit.work.tasks:images/hello')) throw new Error('initializer did not update the window entry')
if (!harness.includes('module: tasks-harness') || !harnessConfig.includes('orbit/tasks: ..')) throw new Error('initializer did not update the harness')
if (!harnessIndex.includes('tasks_harness.dep.module') || !harnessIndex.includes('suite: orbit_work_tasks')) throw new Error('initializer did not update the harness index')
if (!makefile.includes('NS   := orbit.work.tasks')) throw new Error('initializer did not update the Makefile namespace')
if (!readme.includes('# orbit/tasks — Orbit Tasks') || !readme.includes('chicago-desktop/module-template')) throw new Error('initializer did not write the module README with its provenance')
for (const token of ['chicago/module-template', 'chicago.module_template', 'chicago-module-template', 'chicago_module_template', 'Module Template']) {
  for (const [name, content] of [['wippy.yaml', manifest], ['src/_index.yaml', index], ['test/src/_index.yaml', harnessIndex], ['Makefile', makefile]]) {
    if (content.includes(token)) throw new Error(`initializer retained ${token} in ${name}`)
  }
}
if (!manifest.includes('chicago/shell') && !index.includes('chicago/shell')) throw new Error('initializer must leave the dependency on chicago/shell alone')
const second = await initialize(args, target)
if (!second.alreadyInitialized || second.changedFiles !== 0) throw new Error('initializer is not idempotent')
await import(`${pathToFileURL(resolve(target, 'scripts/check-module.mjs')).href}?initialized-test=1`)

console.log('Initializer test passed')
await rm(target, { recursive: true, force: true })
