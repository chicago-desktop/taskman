# Contributing

Read `AGENTS.md`, create a focused branch, and run `make verify` with a local
build of the runtime fork before opening a pull request. Everything in the
repository is English.

Pull requests must say which registry entry or contract they change, include
tests for public behaviour (the model and the window in
`test/src/taskman_test.lua`, the entry in `test/src/window_test.lua`), and
attach or describe the shots in `test/shots/` when the window's look changed. Avoid unrelated formatting and
compatibility layers. Never commit credentials, `wippy.lock` files or local
Wippy state.
