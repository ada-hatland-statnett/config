# Secrets

- `~/.config/` is a **public** git repository. Never write secrets into any
  file under it: no tokens, API keys, passwords, connection strings with
  credentials, private keys, internal hostnames' credentials, or similar.
- Reference secrets indirectly instead: environment variables (e.g.
  `vim.env.SONARQUBE_TOKEN`, `{env:VAR}` in opencode config), or files
  outside `~/.config/` that are not committed.
- If a task seems to require putting a secret in `~/.config/`, stop and ask
  the user instead.

# Tooling

- `lua-language-server` is available for checking Lua files from the CLI
  (installed by Mason; if not on PATH, use
  `~/.local/share/nvim/mason/bin/lua-language-server`):

  ```bash
  lua-language-server --check <dir-or-file> --checklevel=Warning
  ```

  Use it to verify Lua edits (e.g. the Neovim config in `~/.config/nvim`)
  instead of `luac`, which is not installed.
