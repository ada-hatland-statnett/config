# Secrets

- `~/.config/` is a **public** git repository. Never write secrets into any
  file under it: no tokens, API keys, passwords, connection strings with
  credentials, private keys, internal hostnames' credentials, or similar.
- Reference secrets indirectly instead: environment variables (e.g.
  `vim.env.SONARQUBE_TOKEN`, `{env:VAR}` in opencode config), or files
  outside `~/.config/` that are not committed.
- If a task seems to require putting a secret in `~/.config/`, stop and ask
  the user instead.

# Communication

- When a response uses abbreviations or acronyms, end it with an
  "Abbreviations" footnote that spells out each one (e.g. "BFF: Backend
  for Frontend"). Skip very common ones like "e.g." and "etc.".
- When asked to do something simple (e.g. a small edit like adding a line
  to these instructions), do it and respond only with "ait".

# Tooling

- Load the `file-search` skill before any non-trivial codebase search
  (multi-pattern, large trees, structural/AST queries, PDFs/archives,
  code stats). Its tools (`rg`, `fd`, `sg`, `semgrep`, `rga`, `tokei`,
  `scc`) are all installed. Use them through the shell whenever they are
  faster than the built-in `grep`/`glob` tools, e.g. combined
  `rg -e P1 -e P2` walks, `fd ... -X rg`, type filters, structural
  matches, or counting with `rg -c`. Never use `grep -r` or `find` in the
  shell.

- `lua-language-server` is available for checking Lua files from the CLI
  (installed by Mason; if not on PATH, use
  `~/.local/share/nvim/mason/bin/lua-language-server`):

  ```bash
  lua-language-server --check <dir-or-file> --checklevel=Warning
  ```

  Use it to verify Lua edits (e.g. the Neovim config in `~/.config/nvim`)
  instead of `luac`, which is not installed.
