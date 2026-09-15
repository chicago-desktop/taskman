# chicago/taskman — initialize, check, lint, test and publish a module
# of the Chicago shell (chicago/shell).

# The module's root namespace; `make lint` checks it and the harness's.
NS   := chicago.taskman
TYPE := plugin
# Publication visibility for `make publish` on a module the Hub does not have
# yet. Everything under the `chicago` organization is public; set
# VIS=private for a module that must not be.
VIS  := public

# pipefail keeps the runner's exit code while its output is streamed and the
# log is grepped afterwards.
SHELL := bash
.SHELLFLAGS := -o pipefail -ec

# The shell this module runs in declares the `gfx` module, and only the
# runtime fork has it (chicago-desktop/runtime, a build from its releases,
# v0.3.40a-chicago.2 or newer — the one that also resolves the shell and the
# base from their GitHub repositories by tag): the release `wippy` from PATH
# does not load the shell at all and says only "node with ID … not found".
# Point WIPPY at the fork's binary:
#
#   make test WIPPY=~/src/runtime/dist/wippy-linux-amd64
WIPPY ?= $(CURDIR)/../runtime/dist/wippy-linux-amd64

# The shell declares a terminal.host of its own, and the CLI then refuses to
# pick one by itself; the suites run on the application's ordinary host.
TEST_HOST := wippy.terminal:host

.PHONY: init setup check lint test verify release-check publish

# One-time: rename the template's identity to this module's. Refuses to run
# twice with a different identity; see scripts/init-module.mjs --help.
init:
	node scripts/init-module.mjs --organization "$(ORG)" --module "$(MODULE_NAME)" --title "$(TITLE)" $(if $(NAMESPACE),--namespace "$(NAMESPACE)",) $(if $(TAG),--tag "$(TAG)",) $(if $(GITHUB_OWNER),--github-owner "$(GITHUB_OWNER)",)

# Resolve the module's and the harness's dependencies into the two
# wippy.lock files (both ignored by git): the shell and the base from their
# GitHub repositories by tag (the first resolve clones them into
# ~/.wippy/git), the runtime modules from the Hub. A dependency missing from
# the lock stops the boot outright.
setup:
	$(WIPPY) update
	cd test && $(WIPPY) update

# The repository's invariants (identity, dependency ranges, embed list, no
# Cyrillic, no secrets) and, in the pristine template, the initializer.
check:
	node scripts/check-module.mjs
	node scripts/test-initializer.mjs

# Late `local`s first: a local read above its declaration is read as a
# global, that is nil, and nothing fails — `wippy lint` does not see it. Then
# the type check of this module's namespace and of the harness's tests, from
# the harness, which loads the module together with the shell it needs.
lint:
	python3 tools/late-locals.py src test/src
	cd test && $(WIPPY) lint --ns $(NS) --ns app

# The runner exits 0 when it discovers no tests; an empty discovery is always
# a defect here, so the target fails on it.
test:
	mkdir -p test/.wippy
	cd test && $(WIPPY) test --host $(TEST_HOST) 2>&1 | tee .wippy/last-test-run.log && ! grep -q "No tests found" .wippy/last-test-run.log

verify: setup check lint test

release-check: verify
	$(WIPPY) auth status
	$(WIPPY) publish --dry-run --create --module-visibility $(VIS) --module-type $(TYPE)

# `wippy publish` packs src/ and embeds only what wippy.yaml lists under
# `embed:`; check-module.mjs verifies every image pack is there.
publish:
	node scripts/check-module.mjs
	$(WIPPY) auth status
	$(WIPPY) publish --create --module-visibility $(VIS) --module-type $(TYPE)
