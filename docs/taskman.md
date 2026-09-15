# Task Manager

Opens from "Start → Settings → Task Manager". The window is built on the
shell SDK: tabs, tables, frames with titles, gauges, graphs, the status
bar and the button are shared components, the same in cells and in pixels.
The window no longer has its own layout or renderers.

Four tabs: open applications, Wippy processes, performance and the node.
Data refreshes once a second (`definition.interval`). "Refresh", F5 and R
take a new sample immediately. Tabs switch with the mouse, with the ←/→ arrows
while the tab strip has focus, or with keys 1–4. Tables support the wheel, the
scrollbar, arrows, Page Up / Page Down, Home / End. The selection holds on to
the task identifier when a new sample changes the order of rows.

The graphs show the goroutine count and the heap in use; the scale adapts to the
history (`sdk:charts.round_ceiling`). CPU load percentage is not shown:
the `system` module does not provide it. The window's permissions allow reading
the runtime state and the window list, close a window (End Task) and end a
process (End Process, after a warning; the shell and Task Manager itself are
not offered).

`src/window.lua` is the SDK application (`init/view/update`), `model.lua` is
the history, the formats and stable sorting of processes; the graph and the scale
ceiling live in `chicago.shell.sdk:charts`, because any window with a
history of a number needs them.

## Desktop widgets

The module also puts two widgets on the desktop, in the shell's column at the
right edge: **Memory** (`chicago.taskman:memory`, 20×8) — the heap in use in
whole megabytes, a gauge against a round ceiling over a graph of the last two
minutes on the same scale — and **Goroutines** (`chicago.taskman:goroutines`,
20×9) — the goroutine count over a graph of the last two minutes. Each is an
SDK application with `interval = "2s"` and no input: every tick takes one
sample into a ring of 60 (`sample.CAP`, two minutes at a 2 s step) and `view`
returns a tree of the shell's `gadget` kit.

They read the runtime the way the window does, through
`chicago.shell.config:system`, and the heap is the same field, `heap_in_use`.
A refused permission or a missing figure becomes the widget's text — an alert
label with the reason — and stays out of the ring: zero goroutines under a
denial would look healthy and lie. The next good sample brings the figures
back.

A click on a widget opens Task Manager (`meta.opens: chicago.taskman:window`),
or raises it when it is open. The widgets run on every desktop under
`chicago.taskman:widget_scope` (`system.read` and the messages to the
compositor, nothing more); the window keeps `requires: chicago.admin`, so the
compositor opens it only for a person that scope admits.

The shell reads the widget entries when the desktop starts and on
`desktop.refresh`: a new widget appears on the desktop after the shell
restarts.

`src/sample.lua` holds what both widgets share — the ring, one sample, the
ceiling and the two trees; `src/memory.lua` and `src/goroutines.lua` are thin
`app.main` wrappers. Their `definition.system` takes a substitute `system`
for tests, as the window's `definition.snapshot` does.

## Tests

`test/src/taskman_test.lua` checks the SDK layout for overlaps at
three sizes and four tabs, keeping the selection by identifier, and the
live window inside a real compositor: tabs, row selection, "Refresh",
samples. `test/src/taskman_shots_test.lua` draws the four tabs on sample data
into `test/shots/taskman-<tab>.png` through the shell's renderer.
`test/src/sample_test.lua` checks the widgets against a substitute runtime:
the ring keeps sixty samples, the heap is whole megabytes of `heap_in_use`, a
refusal is a label with the reason and not a sample, and both trees lay out
inside the panel body (`width − 2` by `height − 2`) without overlaps, in cells
and at two pixel cell sizes, the graph never squeezed below its minimum rows.
