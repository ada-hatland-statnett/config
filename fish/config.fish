status is-interactive; or exit

fish_default_key_bindings

if status is-interactive
    set -gx SSH_AUTH_SOCK (bash -c 'eval "$(SHELL=/bin/sh keychain --eval --quiet "$HOME/.ssh/id_ed25519")"; printf "%s" "$SSH_AUTH_SOCK"')
    set -g fish_greeting "🐟🐟🐟bem-vinda🐟🐟🐟"
end

function __update_cwd_osc --on-variable PWD
    printf '\e]7;file://%s%s\e\\' $hostname (string escape --style=url $PWD)
end

# Report the active Python virtualenv to the host terminal (nvim) via a custom
# OSC sequence, mirroring the OSC 7 cwd trick above. Fires whenever a venv is
# activated/deactivated so nvim can carry it back to the launching shell.
function __update_venv_osc --on-variable VIRTUAL_ENV
    printf '\e]6666;venv=%s\e\\' "$VIRTUAL_ENV"
end

# Ctrl-C clears the current command line. A running foreground
# job still receives SIGINT from the terminal, so it keeps cancelling
# operations as usual.
bind \cc cancel-commandline
fish_add_path -g "$HOME/.local/bin"

set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"
set -gx XDG_BIN_HOME "$HOME/.local/bin"
set -gx XDG_PICTURES_DIR "$HOME/pictures"
set -gx XDG_DATA_DIRS "/usr/local/share:/usr/share"
set -gx XDG_CONFIG_DIRS "/etc/xdg"

set -gx EDITOR nvim
set -gx SUDO_EDITOR nvim
set -gx PAGER less
set -gx GRIM_DEFAULT_DIR "$HOME/pictures"
set -gx GPG_TTY (tty)
set -gx PYTHON_KEYRING_BACKEND keyring.backends.null.Keyring
set -gx PYTHONSTARTUP "$HOME/.config/python/pythonrc"
set -gx R_LIBS_USER "$HOME/.rlibrary/library"
set -gx TOKEN_DIR "$HOME/.tokens"

if test -r $TOKEN_DIR/.sonarqube_token
    read -gx SONARQUBE_TOKEN <$TOKEN_DIR/.sonarqube_token
else if status is-interactive
    echo "warning: $TOKEN_DIR/.sonarqube_token not found; SONARQUBE_TOKEN unset" >&2
end

if test -r $TOKEN_DIR/.jira_token
    read -gx JIRA_API_TOKEN <$TOKEN_DIR/.jira_token
else if status is-interactive
    echo "warning: $TOKEN_DIR/.jira_token not found; JIRA_TOKEN unset" >&2
end

zoxide init fish | source
alias c 'z'

if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end

# Auto-launch nvim as the default "terminal" (disabled).
# Run `nvim-shell` to opt in for the current shell instead.
# Guard against $NVIM so the shell inside nvim's own :terminal doesn't recurse.

function nvim-shell --description 'Launch nvim, then return to fish inheriting its cwd/venv'
    if set -q NVIM
        return
    end
    set -gx NVIM_CWD_FILE (mktemp)
    set -gx NVIM_VENV_FILE (mktemp)
    nvim $argv
    if test -s "$NVIM_CWD_FILE"
        set -l nvim_cwd (command cat "$NVIM_CWD_FILE")
        test -d "$nvim_cwd"; and cd "$nvim_cwd"
    end
    # Adopt whatever venv was active inside nvim's terminal, so the shell we
    # drop back into has the same Python libraries available.
    if test -s "$NVIM_VENV_FILE"
        set -l nvim_venv (command cat "$NVIM_VENV_FILE")
        if test -n "$nvim_venv" -a -f "$nvim_venv/bin/activate.fish"
            if not test "$VIRTUAL_ENV" = "$nvim_venv"
                functions -q deactivate; and deactivate
                source "$nvim_venv/bin/activate.fish"
            end
        end
    end
    command rm -f "$NVIM_CWD_FILE" "$NVIM_VENV_FILE"
    set -e NVIM_CWD_FILE
    set -e NVIM_VENV_FILE
end

alias v 'nvim'

# `e` opens nvim normally, but inside nvim's :terminal it talks to the parent
# instance instead of nesting a second nvim: no args toggles neo-tree, args are
# opened as buffers in the parent.
function e --wraps=nvim --description 'nvim, or drive the parent nvim from :terminal'
    if not set -q NVIM
        nvim $argv
        return
    end
    if test (count $argv) -eq 0
        # <C-\><C-N> leaves terminal-mode first so the command reaches nvim.
        nvim --server $NVIM --remote-send '<C-\\><C-N>:Neotree toggle<CR>'
    else
        nvim --server $NVIM --remote $argv
        nvim --server $NVIM --remote-send '<C-\\><C-N>'
    end
end
alias s 'nvim main.tex'
alias l 'eza --icons --time-style=long-iso --ignore-glob="__pycache__"'
alias ls 'eza --icons --time-style=long-iso -a'
alias load '.venv/bin/typer insight/loader.py run --ds'


functions -e cd 2>/dev/null
function cd --wraps=cd
    set -l previous_pwd $PWD

    # cd / cd - / cd <path>
    if test (count $argv) -eq 0
        builtin cd ~; or return
    else if test "$argv[1]" = "-"
        if set -q OLDPWD
            builtin cd $OLDPWD; or return
        else
            echo "cd: OLDPWD not set"
            return 1
        end
    else
        builtin cd $argv; or return
    end

    # maintain OLDPWD like other shells
    set -gx OLDPWD $previous_pwd

    # git roots (empty if not in repo)
    set -l old_git_root (git -C "$previous_pwd" rev-parse --show-toplevel 2>/dev/null)
    set -l new_git_root (git -C "$PWD"          rev-parse --show-toplevel 2>/dev/null)

    if set -q VIRTUAL_ENV
        set -l venv_parent (path dirname "$VIRTUAL_ENV")

        # Keep venv if:
        # 1) still under its parent, OR
        # 2) moved within same git repo
        if not string match -q -- "$venv_parent*" "$PWD"
            if test -z "$old_git_root" -o -z "$new_git_root" -o "$old_git_root" != "$new_git_root"
                functions -q deactivate; and deactivate
            end
        end
    else
        # auto-activate local .venv
        if test -f .venv/bin/activate.fish
            source .venv/bin/activate.fish
        end
    end

    l
end

# ---------- Aliases ----------
alias tree 'tree -L 3 -C'
alias mv 'mv --interactive'
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias cal 'cal -m'

# git aliases
alias gs 'git status'
alias gsw 'git switch'
alias gm 'git switch main'
alias gmm 'git pull origin main'
alias gc 'git commit -m'
alias ga 'git add'
alias gp 'git push'
alias gb 'git branch'
alias gr 'git restore'
alias gpl 'git pull'
alias gd 'git branch -d'
alias gl 'git log main..'

# Browse a remote branch (default origin/main) read-only in nvim via a
# temporary worktree. nvim removes the worktree on exit (see
# nvim/lua/custom/autocmds.lua, $REMOTE_VIEW_WORKTREE).
function grv --description 'Browse a remote branch in nvim via a temporary worktree'
    set -l ref (string join '' $argv[1])
    test -n "$ref"; or set ref origin/main
    set -l repo (git rev-parse --show-toplevel); or return
    set -l remote (string split -m1 / $ref)[1]
    git -C $repo fetch --quiet $remote; or return
    set -l dir (mktemp -d /tmp/remote-view-(basename $repo)-XXXXXX)
    git -C $repo worktree add --quiet --detach $dir $ref; or begin
        command rm -rf $dir
        return 1
    end
    # Plain `command nvim` (not nvim-shell): the cwd it would hand back is
    # about to be deleted.
    pushd $dir
    REMOTE_VIEW_REPO=$repo REMOTE_VIEW_WORKTREE=$dir command nvim -R .
    popd
end

function clone
    test (count $argv) -eq 1; or begin
        echo "usage: clone <repo>" >&2
        return 2
    end
    git clone "git@github.com:elhub/$argv[1].git"; or return
    set -l repo_name (basename $argv[1] .git)
    builtin cd $repo_name; or return
end

alias m 'make'
alias mc 'make clean'

# python aliases
alias jn 'jupyter notebook'
alias python 'python3'
alias py 'python3 -q'

# other aliases
alias :q 'exit'
alias close 'disown; exit'
alias j 'jiratui ui -j 1'

# ---------- Functions ----------
function act --description "Activate repo-root .venv if present"
    set -l root (command git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not in a git repo" >&2
        return 1
    end

    set -l venv "$root/.venv/bin/activate.fish"
    if test -f "$venv"
        source "$venv"
    else
        echo "No activate.fish at $venv" >&2
        return 1
    end
end

function zfunc --description "zoxide jump + auto venv + git-aware deactivate + list"
    set -l previous_pwd $PWD
    z $argv; or return

    # --- helper: find nearest .venv up the tree ---
    set -l probe "$PWD"
    set -l found_activate ""
    while true
        if test -f "$probe/.venv/bin/activate.fish"
            set found_activate "$probe/.venv/bin/activate.fish"
            break
        end
        if test "$probe" = "/"
            break
        end
        set probe (path dirname "$probe")
    end

    # git roots (empty if not in repo)
    set -l old_git_root (git -C "$previous_pwd" rev-parse --show-toplevel 2>/dev/null)
    set -l new_git_root (git -C "$PWD"          rev-parse --show-toplevel 2>/dev/null)

    if set -q VIRTUAL_ENV
        set -l venv_parent (path dirname "$VIRTUAL_ENV")

        # deactivate only if outside venv tree AND not same git repo
        if not string match -q -- "$venv_parent*" "$PWD"
            if test -z "$old_git_root" -o -z "$new_git_root" -o "$old_git_root" != "$new_git_root"
                functions -q deactivate; and deactivate
            end
        end
    end

    # activate if no venv active after possible deactivation
    if not set -q VIRTUAL_ENV
        if test -n "$found_activate"
            source "$found_activate"
        end
    end

    l
end
alias f 'zfunc'

function inproj
    test (count $argv) -eq 1; or begin
        echo "usage: inproj <dir>" >&2
        return 2
    end
    mkdir -p -- $argv[1]; or return
    builtin cd -- $argv[1]; or return
    mkdir -p python data sql
    builtin cd python
end

function lazygit
    test (count $argv) -ge 1; or begin
        echo "usage: lazygit <commit message>" >&2
        return 2
    end
    git add -u
    git commit -m "$argv[1]"
    git push
end

function ranger-cd
    set -l tempfile (mktemp -t tmp.XXXXXX)
    /usr/bin/ranger --choosedir="$tempfile" $argv
    if test -f "$tempfile"
        set -l chosen (cat -- "$tempfile")
        if test -n "$chosen"; and test "$chosen" != "$PWD"
            builtin cd -- "$chosen"
        end
        rm -f -- "$tempfile"
    end
end

function cl
    test (count $argv) -eq 1; or begin
        echo "usage: cl <file>" >&2
        return 2
    end
    cat -- "$argv[1]" | clip.exe
end


set -g fish_color_command normal
set -g fish_color_param normal
set -g fish_color_normal normal

# Optional: other bits
set -g fish_color_quote yellow
set -g fish_color_error brred
set -gx LD_LIBRARY_PATH /opt/oracle/instantclient_23_26 $LD_LIBRARY_PATH
set -gx PATH /opt/oracle/instantclient_23_26 $PATH
set -gx TNS_ADMIN /opt/oracle/instantclient_23_26/network/admin

function authenticate_to_github --description "Configure gh CLI auth from ~/.github_token"
    set -l token_file "$HOME/.github_token"
    set -l username (whoami)

    # Already authenticated? nothing to do.
    if gh auth status >/dev/null 2>&1
        return 0
    end

    if not test -f "$token_file"
        echo "Error: GitHub token file not found at $token_file" >&2
        echo "Create it with: gh auth login; gh auth token > $token_file; and chmod 600 $token_file" >&2
        return 1
    end

    set -l token (tr -d '\n\r' < "$token_file" 2>/dev/null)
    if test -z "$token"
        echo "Error: Could not read token from $token_file or file is empty" >&2
        return 1
    end

    mkdir -p ~/.config/gh

    printf 'github.com:\n    oauth_token: %s\n    user: %s\n    git_protocol: https\n' \
        "$token" "$username" > ~/.config/gh/hosts.yml
    chmod 600 ~/.config/gh/hosts.yml

    if gh auth setup-git >/dev/null 2>&1
        echo "GitHub CLI authentication configured successfully"
    else
        echo "Warning: git integration setup failed, but auth should still work" >&2
    end

    if gh auth status >/dev/null 2>&1
        echo "Authenticated as "(gh api user --jq .login)
    else
        echo "Authentication setup failed" >&2
        return 1
    end
end

if type -q gh
    authenticate_to_github
end

starship init fish | source
