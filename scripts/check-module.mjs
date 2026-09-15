import { execFileSync } from 'node:child_process'
import { access, readFile, readdir, stat } from 'node:fs/promises'
import { dirname, extname, relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { TEMPLATE_REPOSITORY, templateTokenMap } from './init-module.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
let failed = false

function report(message) {
  console.error(`check-module: ${message}`)
  failed = true
}

async function exists(path) {
  try { await access(path); return true } catch { return false }
}

async function walk(directory) {
  const out = []
  for (const item of await readdir(directory, { withFileTypes: true })) {
    if (item.isDirectory() && ['.git', '.wippy', '.local', 'node_modules'].includes(item.name)) continue
    const full = resolve(directory, item.name)
    if (item.isDirectory()) out.push(...await walk(full))
    else if (item.isFile()) out.push(full)
  }
  return out
}

const posix = (path) => relative(root, path).split(sep).join('/')

// Copies of the shell's documentation: docs/sdk.md and the skill. They link
// to the shell's other documents, which are not here, and the shell's
// repository is canonical for them; so they are checked for nothing but
// Cyrillic and secrets.
const vendoredDoc = (path) => /^(docs\/sdk\.md|skills\/|\.claude\/skills\/)/.test(posix(path))

const config = JSON.parse(await readFile(resolve(root, '.kickside-module.json'), 'utf8'))
const identity = config.identity
const moduleManifest = await readFile(resolve(root, 'wippy.yaml'), 'utf8')
const rootIndex = await readFile(resolve(root, 'src/_index.yaml'), 'utf8')

if (!moduleManifest.includes(`organization: ${identity.organization}`)) report('wippy.yaml organization differs from template identity')
if (!moduleManifest.includes(`module: ${identity.module}`)) report('wippy.yaml module differs from template identity')
if (/^version:/m.test(moduleManifest)) report('wippy.yaml must not pin a release version; the publisher selects it')
if (!rootIndex.includes(`namespace: ${identity.namespace}`)) report('root ns.definition namespace differs from template identity')

// Dependencies name a compatibility range; the lock holds the exact version.
// Image packs and other fs.directory entries are packed only when wippy.yaml
// lists them under `embed:` — `wippy publish` packs src/ and nothing else,
// and a module published without its pictures draws none.
const embedded = new Set()
const embedBlock = moduleManifest.match(/^embed:\s*\n((?:[ \t]+-[^\n]*\n?)+)/m)
for (const line of (embedBlock?.[1] ?? '').split('\n')) {
  const item = line.replace(/^\s*-\s*/, '').replace(/^['"]|['"]$/g, '').trim()
  if (item) embedded.add(item)
}
const yamlFiles = (await walk(resolve(root, 'src'))).filter((path) => /\.ya?ml$/.test(path))
for (const file of yamlFiles) {
  const lines = (await readFile(file, 'utf8')).split('\n')
  const namespace = lines.find((line) => /^namespace:\s*/.test(line))?.replace(/^namespace:\s*/, '').trim() ?? identity.namespace
  let entryName = null
  for (let index = 0; index < lines.length; index += 1) {
    const named = lines[index].match(/^\s*-\s*name:\s*(\S+)\s*$/)
    if (named) entryName = named[1]
    if (/^\s*kind:\s*ns\.dependency\s*$/.test(lines[index])) {
      const nearby = lines.slice(Math.max(0, index - 8), index + 1)
      const versionLine = [...nearby].reverse().find((line) => /^\s*(?:-\s*)?version:\s*/.test(line))
      const version = versionLine?.replace(/^\s*(?:-\s*)?version:\s*/, '').replace(/^['"]|['"]$/g, '')
      if (!version || !(version === '*' || /^(>=|<=|>|<|\^|~)/.test(version))) {
        report(`${posix(file)}:${index + 1} ns.dependency must declare a compatibility range, never an exact version`)
      }
    }
    if (/^\s*kind:\s*fs\.directory\s*$/.test(lines[index])) {
      const id = `${namespace}:${entryName}`
      if (!entryName || !embedded.has(id)) report(`${posix(file)}:${index + 1} fs.directory ${id} is not listed under embed: in wippy.yaml; wippy publish packs only src/ and what embed: names`)
    }
  }
}

// A test file that is not in the run_cases form is counted, printed green
// and never executed.
const testFiles = (await walk(resolve(root, 'test/src'))).filter((path) => /_test\.lua$/.test(path))
if (testFiles.length === 0) report('test/src has no *_test.lua; the template ships suites')
for (const file of testFiles) {
  const content = await readFile(file, 'utf8')
  if (!/test\.run_cases\(/.test(content)) report(`${posix(file)} is not in the run_cases form (local run_cases = test.run_cases(define_tests)); such a file passes without running`)
}

// English only, the owner's rule for every repository of the shell: code,
// comments, meta.comment, documentation, test names.
const allFiles = await walk(root)
const cyrillic = new RegExp(`[${String.fromCodePoint(0x400)}-${String.fromCodePoint(0x4ff)}]`)
for (const file of allFiles) {
  const info = await stat(file)
  if (info.size > 4 * 1024 * 1024) continue
  const buffer = await readFile(file)
  if (buffer.includes(0)) continue
  const content = buffer.toString('utf8')
  const line = content.split('\n').findIndex((text) => cyrillic.test(text))
  if (line >= 0) report(`${posix(file)}:${line + 1} contains Cyrillic; everything here is English`)
}

const markdownFiles = allFiles.filter((path) => extname(path) === '.md' && !vendoredDoc(path))
for (const page of markdownFiles) {
  const markdown = await readFile(page, 'utf8')
  const sourceRelative = posix(page)
  const lines = markdown.split('\n')
  let fenced = false
  for (let index = 0; index + 1 < lines.length; index += 1) {
    if (/^\s*(```|~~~)/.test(lines[index])) { fenced = !fenced; continue }
    if (!fenced && /^\s*\|.*\|\s*$/.test(lines[index])
        && /^\s*\|(?:\s*:?-{3,}:?\s*\|)+\s*$/.test(lines[index + 1])) {
      report(`${sourceRelative}:${index + 1} uses a pipe table unsupported by the Hub renderer`)
    }
  }
  for (const match of markdown.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
    const target = match[1].trim().replace(/^<|>$/g, '')
    if (!target || target.startsWith('#') || /^[a-z][a-z0-9+.-]*:/i.test(target)) continue
    const fileTarget = target.split('#', 1)[0]
    if (!fileTarget) continue
    const resolved = resolve(dirname(page), decodeURIComponent(fileTarget))
    if (!resolved.startsWith(`${root}${sep}`) || !await exists(resolved)) report(`${sourceRelative} has a broken local link: ${target}`)
  }
}

const secretPatterns = [
  /\b(?:gh[oprsu]_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{20,}|wpy_[A-Za-z0-9_-]{20,})\b/,
  /-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----/,
]
for (const file of allFiles) {
  const info = await stat(file)
  if (info.size > 4 * 1024 * 1024) continue
  const buffer = await readFile(file)
  if (buffer.includes(0)) continue
  const content = buffer.toString('utf8')
  if (secretPatterns.some((pattern) => pattern.test(content))) report(`${posix(file)} contains credential-like material`)
}

if (config.initialized) {
  const customizable = allFiles.filter((path) => !vendoredDoc(path) && !path.includes(`${sep}scripts${sep}`)
    && path !== resolve(root, '.kickside-module.json'))
  const escapeLiteral = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  // When the identity's own value is a superstring of the template token
  // (module module-template-demo → acme/module-template-demo), a plain
  // substring test cannot tell leftover from legitimate identity; the
  // lookahead excludes exactly the legitimate continuation.
  const leftoverPatterns = [...templateTokenMap(identity)].map(([token, current]) => {
    const suffix = current.startsWith(token) && current !== token ? `(?!${escapeLiteral(current.slice(token.length))})` : ''
    return [token, new RegExp(escapeLiteral(token) + suffix)]
  })
  // The bare module name is a leftover too — unless this module's own
  // identity legitimately contains it, in which case the word cannot
  // distinguish scaffold residue.
  const identityContainsTemplate = /module[-_]template/i.test(Object.values(identity).join(' '))
  for (const file of customizable) {
    const buffer = await readFile(file)
    if (buffer.includes(0)) continue
    // The template's URL is provenance ("made from …"), not a leftover.
    const content = buffer.toString('utf8').split(TEMPLATE_REPOSITORY).join('')
    for (const [token, pattern] of leftoverPatterns) {
      if (pattern.test(content)) report(`${posix(file)} retains template token ${token}`)
    }
    if (!identityContainsTemplate && /\bmodule[-_]template\b/i.test(content)) {
      report(`${posix(file)} retains a bare "module-template" template word`)
    }
  }
}

try {
  const tracked = execFileSync('git', ['ls-files'], {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  }).trim().split('\n').filter(Boolean)
  for (const path of tracked) {
    if (path === 'wippy.lock' || path === 'test/wippy.lock' || path.startsWith('.wippy/') || path.startsWith('test/.wippy/')
        || path.startsWith('test/shots/') || path.includes('/node_modules/')
        || path.endsWith('.wapp') || path.endsWith('.env') || path.endsWith('.log')) {
      report(`generated or sensitive file is tracked: ${path}`)
    }
  }
} catch {
  // The repository may be checked before its first git init. All other checks still run.
}

if (failed) process.exit(1)
console.log(`Module checks passed for ${identity.organization}/${identity.module}`)
