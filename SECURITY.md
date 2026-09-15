# Security policy

Do not open a public issue containing credentials, private data, or a working
exploit. Use GitHub's private vulnerability reporting for this repository or
contact the Wippy maintainers through the security channel listed by the
organization.

Before publishing a module:

- run `make release-check`;
- inspect the Git diff and the tracked-file list (`make check` refuses
  tracked lock files, `.wippy/`, packs and logs);
- keep Hub tokens, `.env`, `.wippy/`, databases and module packs outside Git;
- give a window only the policy it needs — the shell's
  `chicago.shell.security:view_state` for a view window, plus a policy of
  the module's own for the resources it actually reads;
- read files through a declared `fs` resource under that policy, never by a
  system path;
- validate untrusted input at the window's boundary and never log private
  payloads.
