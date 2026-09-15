# chicago/taskman — Task Manager

Task Manager for the Chicago desktop in the terminal
([chicago/shell](https://github.com/chicago-desktop/shell)): Start →
Settings → **Task Manager**. It shows the runtime itself — the open windows,
the Wippy processes, memory and goroutines over time, the node and the
cluster — refreshed once a second. For administrators only.

Four tabs:

- **Applications** — the open windows, from the compositor. End Task asks the
  window to close, and ends it on the second press.
- **Processes** — the runtime's processes: their entry, actor, state, steps
  and how long they run, sorted stably by entry and pid. End Process warns
  first and ends the process on Yes; the shell and Task Manager itself are
  not offered.
- **Performance** — goroutines and the heap in use as graphs whose scale
  follows the history, and the memory figures. There is no CPU load in
  percent on purpose: the runtime does not compute it, and the window is not
  allowed to read `/proc`; goroutines and the heap are the honest load of
  the runtime.
- **Node** — the host, the process hosts, the node's role and the cluster's
  members.

"Refresh", F5 and R take a new sample at once. A permission refused to the
window is named on screen, never shown as zero.

## Rights and who may open it

The window reads the numbers itself, with the `system` module, under its own
policy `chicago.taskman:window_scope`: `system.read` for the runtime,
`process.context` / `process.registry` / `process.send` to ask the compositor
and close a window, and `process.terminate` for End Process. That wide
policy is the point of the program — it ends any runtime process, other
people's desktops' among them — and so the window names
`requires: chicago.admin`: the base's compositor asks the logged-on person's
scope before opening it (`app.security:admin` has it through `*`). Under a
terminal.ssh host anyone with an account logs on; without the field Task
Manager would open for everyone.

The module asks nothing of the application: the Start menu finds the window
from its registry entry. Its picture is the module's own,
`chicago.taskman:images/taskmgr` — an image pack of the shell under
`assets/images` (32 and 16 px) copied from the shell's icon set, an interim icon set (see `assets/images/SOURCE.md`); the pictures of
the windows on the Applications tab come with the compositor's list.

## Inside

- `chicago.taskman:window` — the window, an application on the shell's SDK
  (`chicago.shell.sdk:app`): tabs, tables, framed groups, gauges, graphs, the
  status bar and the button are the SDK's components, the same in cells and
  in pixels.
- `chicago.taskman:model` — the history, the formats and the stable sorting
  of processes, pure; the graph and the scale ceiling come from
  `chicago.shell.sdk:charts`.

More in [docs/taskman.md](docs/taskman.md).

## Developing

```bash
make setup     # resolve the dependencies (once, and after changing them)
make check     # the repository's invariants
make lint      # late locals, then wippy lint of this namespace and the harness
make test      # the harness in test/, with test/shots/taskman-<tab>.png
make publish   # publish a release, after `wippy auth login`
```

The suites: `window_test` (the entry, the picture, the policy),
`taskman_test` (the model, the layout at three sizes on four tabs, the
selection kept by id, End Task and End Process, and the live window inside a
real pixel compositor — `taskman_composer` in the harness) and
`taskman_shots_test` (the four tabs on sample data through the shell's
renderer).

**A build of the runtime fork from its releases is required**
([chicago-desktop/runtime](https://github.com/chicago-desktop/runtime),
`v0.3.40a-chicago.2` or newer): it resolves the shell and the base from
GitHub by tag, and the shell declares the `gfx` module, which the release
runtime does not have — `wippy` from PATH does not load the shell at all.
The Makefile's `WIPPY` names the build; override it with `make test WIPPY=…`.

The window SDK is documented in [docs/sdk.md](docs/sdk.md), a copy of the
shell's guide, and the skill for agents in
[skills/wippy-window-app/SKILL.md](skills/wippy-window-app/SKILL.md); the
rules of this repository are in [AGENTS.md](AGENTS.md).

Made from [the Chicago module template](https://github.com/chicago-desktop/module-template) for
modules of the Chicago shell. Repository:
https://github.com/chicago-desktop/taskman.

## Licence

MIT.
