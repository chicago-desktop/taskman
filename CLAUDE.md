# Agent instructions

Read and follow [AGENTS.md](AGENTS.md) in full before changing this
repository: the rules (English only, the local runtime build only, tests from
the harness), the commands and the traps are there. The window SDK is
[docs/sdk.md](docs/sdk.md); the skill `wippy-window-app` in `.claude/skills/`
is the shell's, and its work sequence applies here.

What to know before the first edit:

- **Only a build of the runtime fork runs this module** (chicago-desktop/runtime,
  branch `wippy-projects`): the shell declares `gfx`, and a release `wippy`
  refuses to load it with `node with ID {gfx :gfx} not found`. The Makefile's
  `WIPPY` names the build; `make lint` with a release `wippy` verifies nothing.
- **`make test` runs the harness in `test/`** with `--host
  wippy.terminal:host`; it writes `test/shots/taskman-<tab>.png` (the four tabs),
  the window as the shell's renderer drew it. Look at the picture: the geometry checks do not
  see a wrong colour or a caption a pixel off.
- **A `local` declared below the function that reads it is a nil global**,
  silently — `python3 tools/late-locals.py src test/src` finds it, `wippy
  lint` does not.
- **An unquoted `: ` in a YAML comment or a `meta.comment`** breaks the whole
  index and the boot.
- **A test file not in the `run_cases` form is green without running**:
  `local run_cases = test.run_cases(define_tests)` and
  `return {run = function(options) return run_cases(options) end}`. Break a
  new test on purpose once.
- **`wippy publish` packs only `src/`**; an image pack outside it ships only
  when `wippy.yaml` lists it under `embed:`.
- **`${env:…}` in a registry entry** resolves against the environment
  registry, not the OS; `exec` does not inherit the OS environment either.
