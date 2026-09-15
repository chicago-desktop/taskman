import { readFile, readdir, stat, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptPath = fileURLToPath(import.meta.url)
const defaultRoot = resolve(dirname(scriptPath), '..')

// The template's own repository. A module made from the template keeps this
// URL in its README as provenance; check-module.mjs does not count that one
// occurrence as a leftover.
export const TEMPLATE_REPOSITORY = 'https://github.com/chicago-desktop/module-template'

function usage() {
  return `Usage:
  node scripts/init-module.mjs \\
    --organization <hub-org> --module <module-name> --title <display-name> \\
    [--namespace <root.namespace>] [--tag <org-module-slug>] \\
    [--github-owner <owner>]

Renames the template's identity (chicago/module-template, the namespace
chicago.module_template, the title "Module Template") to the module's in
every source, test and configuration file, and writes a README for the
module. The initializer is idempotent for the same identity and refuses to
rewrite an already-initialized checkout to a different identity.`
}

function parseArgs(argv) {
  const out = {}
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index]
    if (token === '--help' || token === '-h') return { help: true }
    if (!token.startsWith('--')) throw new Error(`unexpected argument: ${token}`)
    const key = token.slice(2)
    const value = argv[index + 1]
    if (!value || value.startsWith('--')) throw new Error(`missing value for ${token}`)
    if (Object.hasOwn(out, key)) throw new Error(`duplicate option: ${token}`)
    out[key] = value
    index += 1
  }
  return out
}

function namespacePart(value) {
  return value.toLowerCase().replace(/-/g, '_')
}

function snake(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')
}

function sameIdentity(left, right) {
  return ['organization', 'module', 'namespace', 'tag', 'title', 'githubOwner']
    .every((key) => left?.[key] === right[key])
}

// Template identity tokens mapped to what they become for a given identity.
// check-module.mjs uses this to scan for scaffold leftovers without false
// positives when the replacement is a superstring of the token (a module
// actually named module-template-demo yields acme/module-template-demo,
// which contains "acme/module-template" without being a leftover).
export function templateTokenMap(identity) {
  const sqlPrefix = identity.namespace.replace(/\./g, '_')
  return new Map([
    ['chicago/module-template', `${identity.organization}/${identity.module}`],
    ['chicago.module_template', identity.namespace],
    ['chicago-module-template', identity.tag],
    ['chicago_module_template', sqlPrefix],
    ['CHICAGO_MODULE_TEMPLATE', sqlPrefix.toUpperCase()],
    ['Module Template', identity.title],
  ])
}

// The README a module gets in place of the template's: the template's
// README explains the template, and a module's should explain the module.
export function moduleReadme(identity) {
  const { organization, module: moduleName, namespace, title, githubOwner } = identity
  return `# ${organization}/${moduleName} — ${title}

A module of the Chicago shell for the terminal desktop
([chicago/shell](https://github.com/chicago-desktop/shell)): it adds
**${title}** to the Start menu under Programs. Describe here what the
window does and how it is used.

## Inside

- \`${namespace}:view\` — the window as data: a pure library with the
  component tree of a model and what an action does to it; the tests
  exercise it without a compositor.
- \`${namespace}:window\` — the process: runs \`view\` on the shell's SDK
  (\`chicago.shell.sdk:app\`).
- \`${namespace}:images\` — the module's pictures, an image pack of the
  shell (\`assets/images/{32,16}/<name>.png\`), named
  \`${namespace}:images/<name>\`.

The module depends on \`chicago/shell\` (the SDK, the image packs) and
\`chicago/tui-desktop\` (the compositor), both resolved from their GitHub
repositories by tag (\`make setup\`; no working copy of the shell is needed
beside the module). It asks nothing of the application.

## Developing

\`\`\`bash
make setup     # resolve the dependencies (once, and after changing them)
make check     # the repository's invariants
make lint      # late locals, then wippy lint of this namespace and the harness
make test      # the harness in test/: the view, the window, a shot in test/shots/
make publish   # to the Hub, after \`wippy auth login\`
\`\`\`

**A build of the runtime fork from its releases is required**
([chicago-desktop/runtime](https://github.com/chicago-desktop/runtime),
\`v0.3.40a-chicago.2\` or newer): it resolves the shell and the base from
GitHub by tag, and the shell declares the \`gfx\` module, which the release
runtime does not have — \`wippy\` from PATH does not load the shell at all.
The Makefile's \`WIPPY\` names the build; override it with \`make test WIPPY=…\`.

The window SDK is documented in [docs/sdk.md](docs/sdk.md), a copy of the
shell's guide, and the skill for agents in
[skills/wippy-window-app/SKILL.md](skills/wippy-window-app/SKILL.md); the
rules of this repository are in [AGENTS.md](AGENTS.md).

Made from [the Chicago module template](${TEMPLATE_REPOSITORY}) for
modules of the Chicago shell. Repository:
https://github.com/${githubOwner}/${moduleName}.

## Licence

MIT.
`
}

export async function initialize(argv, root = defaultRoot) {
  const args = parseArgs(argv)
  if (args.help) {
    console.log(usage())
    return { help: true }
  }

  const organization = args.organization
  const moduleName = args.module
  const title = args.title
  if (!organization) throw new Error('--organization is required')
  if (!moduleName) throw new Error('--module is required')
  if (!title) throw new Error('--title is required')
  if (!/^[a-z][a-z0-9-]{1,38}$/.test(organization)) throw new Error('--organization must be a lowercase Hub/GitHub slug')
  if (!/^[a-z][a-z0-9-]{1,62}$/.test(moduleName)) throw new Error('--module must be a lowercase module slug')
  if (title.length > 80 || /[\r\n]/.test(title)) throw new Error('--title must be one line and at most 80 characters')
  if (/[/:|`]/.test(title)) throw new Error('--title goes into YAML values and a menu folder name; no slashes, colons, pipes or backticks')

  const namespace = args.namespace ?? `${namespacePart(organization)}.${namespacePart(moduleName)}`
  const tag = args.tag ?? `${organization}-${moduleName}`
  // The Hub organization `chicago` lives on GitHub as `chicago-desktop`; any
  // other organization is assumed to use the same name in both places.
  const githubOwner = args['github-owner'] ?? (organization === 'chicago' ? 'chicago-desktop' : organization)
  if (!/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/.test(namespace)) throw new Error('--namespace must contain at least two lowercase dot-separated segments')
  if (!/^[a-z][a-z0-9.-]*-[a-z0-9.-]+$/.test(tag)) throw new Error('--tag must be a lowercase slug containing a hyphen')
  if (!/^[A-Za-z0-9_.-]+$/.test(githubOwner)) throw new Error('--github-owner is not a valid GitHub owner')

  const identity = { organization, module: moduleName, namespace, tag, title, githubOwner }
  const configPath = resolve(root, '.kickside-module.json')
  const config = JSON.parse(await readFile(configPath, 'utf8'))
  if (config.initialized) {
    if (sameIdentity(config.identity, identity)) {
      console.log(`Already initialized as ${organization}/${moduleName}; nothing to change.`)
      return { identity, changedFiles: 0, alreadyInitialized: true }
    }
    throw new Error(`checkout is already initialized as ${config.identity.organization}/${config.identity.module}; clone a fresh template to create another module`)
  }

  const moduleSnake = snake(moduleName)
  const sqlPrefix = namespace.replace(/\./g, '_')
  const envPrefix = sqlPrefix.toUpperCase()
  const repository = `https://github.com/${githubOwner}/${moduleName}`
  const replacements = [
    [TEMPLATE_REPOSITORY, repository],
    ['chicago/module-template', `${organization}/${moduleName}`],
    ['chicago.module_template', namespace],
    ['chicago-module-template', tag],
    ['CHICAGO_MODULE_TEMPLATE', envPrefix],
    ['chicago_module_template', sqlPrefix],
    ['module_template_harness', `${moduleSnake}_harness`],
    ['module-template-harness', `${moduleName}-harness`],
    ['Module Template Test Harness', `${title} Test Harness`],
    ['Programs/Module Template', `Programs/${title}`],
    ['Module Template', title],
    ['organization: chicago', `organization: ${organization}`],
    ['module: module-template', `module: ${moduleName}`],
  ]
  // All replacements happen in one pass over the content, longest pattern
  // first, so replaced text is never rescanned. A module name that itself
  // starts with "module-template" therefore cannot be corrupted by a later
  // pattern matching inside an earlier replacement's output. Bare-word
  // alternatives run last as prose fallbacks: any "module-template" or
  // "module_template" the longer literals did not claim becomes the module
  // name, so no scaffold wording leaks into shipped metadata. The words
  // "chicago" (the shell's organization: chicago/shell stays) and "template"
  // alone are never touched.
  const escapeLiteral = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const byLength = replacements.map(([from]) => from).sort((a, b) => b.length - a.length)
  const replacementMap = new Map(replacements)
  const replacementPattern = new RegExp(
    [...byLength.map(escapeLiteral), '\\bmodule-template\\b', '\\bmodule_template\\b'].join('|'), 'g')
  const applyReplacements = (text) => text.replace(replacementPattern, (match) => {
    if (replacementMap.has(match)) return replacementMap.get(match)
    return match === 'module_template' ? moduleSnake : moduleName
  })
  // docs/, skills/ and .claude/ are copies of the shell's documentation and
  // describe the shell, not this module; scripts/ carry the template tokens
  // as data; README.md is written anew below.
  const excludedDirectories = new Set(['.git', '.wippy', '.local', 'node_modules', 'docs', 'skills', '.claude', 'scripts'])
  const excludedFiles = new Set([resolve(root, 'README.md'), configPath])

  async function walk(directory) {
    const files = []
    for (const item of await readdir(directory, { withFileTypes: true })) {
      if (item.isDirectory() && excludedDirectories.has(item.name)) continue
      const full = resolve(directory, item.name)
      if (item.isDirectory()) files.push(...await walk(full))
      else if (item.isFile() && !excludedFiles.has(full)) files.push(full)
    }
    return files
  }

  let changedFiles = 0
  for (const file of await walk(root)) {
    const info = await stat(file)
    if (info.size > 4 * 1024 * 1024) continue
    const buffer = await readFile(file)
    if (buffer.includes(0)) continue
    const before = buffer.toString('utf8')
    const content = applyReplacements(before)
    if (content !== before) {
      await writeFile(file, content)
      changedFiles += 1
    }
  }

  await writeFile(resolve(root, 'README.md'), moduleReadme(identity))
  changedFiles += 1

  config.initialized = true
  config.identity = identity
  await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`)

  console.log(`Initialized ${organization}/${moduleName}`)
  console.log(`  namespace: ${namespace}`)
  console.log(`  title: ${title}`)
  console.log(`  repository: ${repository}`)
  console.log(`Updated ${changedFiles} files. Next: make setup && make test`)
  return { identity, changedFiles, alreadyInitialized: false }
}

if (process.argv[1] && resolve(process.argv[1]) === scriptPath) {
  try {
    await initialize(process.argv.slice(2))
  } catch (error) {
    console.error(`init-module: ${error instanceof Error ? error.message : String(error)}`)
    process.exitCode = 1
  }
}
