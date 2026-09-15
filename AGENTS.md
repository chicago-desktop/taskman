# Operating contract for this module

A module of the Windows 95 shell for the terminal desktop (`windows/shell` on
`windows/tui-desktop`), made from the Windows module template. Read this file
in full before changing the repository.

## Rules

- **English only**: code, comments, `meta.comment`, YAML comments, documents,
  test names, commit messages. `make check` refuses Cyrillic anywhere.
- **The local runtime build only.** The shell declares the `gfx` module,
  which only a build of the runtime fork has (wippy-windows/runtime, branch
  `wippy-projects`); a release `wippy` does not load the shell and says only
  `node with ID {gfx :gfx} not found`. `make lint` and `make test` use the
  build the Makefile's `WIPPY` names; a release `wippy lint` answers "clean"
  to `gfx` code because it cannot see it.
- **Run the tests from the harness** (`make test`, that is `wippy test
  --host wippy.terminal:host` in `test/`), never from the module root: the
  harness is the application that boots the module with the shell. The host
  is named because the shell brings a terminal host of its own.
- **The window is data, the process is thin.** Everything a test should see
  goes into the pure `view` library (`src/view.lua`); `src/window.lua` runs
  it with `app.main`. Use the SDK as documented in `docs/sdk.md` and the
  skill in `skills/wippy-window-app/SKILL.md`: the compositor owns the frame,
  the tree is plain tables, every interactive component has a stable `id`.
- **Report actual tests and what they saw**: the shot in `test/shots/` is
  evidence for the eye; a green run is not proof a window looks right.

## Commands

```bash
make setup          # resolve dependencies from the Hub (both wippy.lock files)
make check          # identity, dependency ranges, embed list, test form, no Cyrillic
make lint           # tools/late-locals.py, then wippy lint of this namespace and the harness
make test           # the harness's suites; writes test/shots/*.png
make verify         # all of the above; what CI runs
make release-check  # verify + an authenticated publish dry run
make publish        # public by default; VIS=private otherwise
```

Do not weaken a check to land a change. Fix the source, or correct the check
when its stated invariant is objectively wrong.

## Traps

- **A `local` declared below the function that reads it is a nil global.**
  No error, and the symptom looks like anything else. `tools/late-locals.py`
  catches it (`make lint` runs it first); declare everything a function calls
  above that function.
- **An unquoted `: ` in a YAML comment or a `meta.comment` breaks the whole
  index** and the boot with it. Quote such comments.
- **A test file in the wrong form is green without running.** The form is
  `local run_cases = test.run_cases(define_tests)` …
  `return {run = function(options) return run_cases(options) end}`; the
  `return {run = run}` form is counted, printed green in under a millisecond
  and never executed. Break a new test once and see it go red. The harness
  has `test.eq / is_nil / not_nil / is_true / is_false`; there is no
  `test.expect`.
- **`wippy publish` packs only `src/`** and embeds only the `fs.directory`
  entries `wippy.yaml` lists under `embed:`; an image pack outside the list
  is not in the package. `make check` verifies it.
- **`${env:…}` in a registry entry resolves against the environment
  registry, not the OS**, and `exec` does not inherit the OS environment:
  the harness hands `HOME` and `PATH` to the base in `test/.wippy.yaml`.
- **Do not end a function with a bare `return <yielding runtime call>(…)`**
  (`ch:receive()`, `client:send()`, a `time.after(…):receive()`): go-lua
  drops such a tail call from a coroutine's base frame, and the call returns
  nothing in 0 ms with no error. Assign, then return.
- **Mutable state shared by a function and its closures lives in a table**,
  not in locals: after an error caught by `pcall`, go-lua stops sharing a
  local between a closure and its owner.

## Publishing

- `wippy auth login` stores Hub credentials outside the repository.
- Source manifests do not pin the next release version; the publisher selects
  it, and a published version is immutable — bump instead of correcting.
- Dependencies declare a range (`version: "*"` or a genuine constraint), never
  an exact version copied from a lock. Both `wippy.lock` files are ignored.
- Run `make release-check`, inspect `git diff`, ensure `git status` is clean,
  then publish from the default branch only.
