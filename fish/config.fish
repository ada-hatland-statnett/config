status is-interactive; or exit

fish_default_key_bindings

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
alias mosh 'mosh --no-init'
alias tree 'tree -L 3 -C'
alias mv 'mv --interactive'
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias cal 'cal -m'
alias t 'tmux'

# git aliases
alias gs 'git status'
alias gsw 'git switch'
alias gm 'git switch main'
alias gmm 'git merge main'
alias gc 'git commit -m'
alias ga 'git add'
alias gp 'git push'
alias gb 'git branch'
alias gr 'git restore'
alias gpl 'git pull'
alias gd 'git branch -d'
alias gl 'git log main..'

alias m 'make'
alias mc 'make clean'

# python aliases
alias jn 'jupyter notebook'
alias python 'python3'
alias py 'python3 -q'

# other aliases
alias :q 'exit'
alias pac 'sudo pacman -Syu'
alias close 'disown; exit'
alias tlmgr '/usr/share/texmf-dist/scripts/texlive/tlmgr.pl --usermode'

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

function fish_prompt
    set -l last_status $status

    set -l host_short (prompt_hostname)
    set host_short (string split '.' -- $host_short)[1]

    set -l cwd (prompt_pwd)

    set -l git_part ""
    if command git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l branch (command git symbolic-ref --short HEAD 2>/dev/null)
        if test -z "$branch"
            set branch (command git rev-parse --short HEAD 2>/dev/null)
        end
        if test -n "$branch"
            set git_part "$branch"
        end
    end

    set -l c_status (set_color brred)
    set -l c_host   (set_color normal)
    set -l c_cwd    (set_color blue)      # was invalid numeric 27
    set -l c_git    (set_color bryellow)
    set -l c_reset  (set_color normal)

    # Prevent [] from being interpreted as index: split output pieces
    echo -n $c_status"["$last_status"]"$c_reset" "
    echo -n $c_host$host_short":"$c_reset
    echo -n $c_cwd$cwd$c_reset
    if test -n "$git_part"
        echo -n " "$c_git$git_part$c_reset
    end

    echo
    echo -n " ▪ "
end

source ~/.config/fish/functions/fish_prompt.fish
commandline -f repaint

set -g fish_color_command normal
set -g fish_color_param normal
set -g fish_color_normal normal

# Optional: other bits
set -g fish_color_quote yellow
set -g fish_color_error brred
set -gx LD_LIBRARY_PATH /opt/oracle/instantclient_23_26 $LD_LIBRARY_PATH
set -gx PATH /opt/oracle/instantclient_23_26 $PATH
set -gx TNS_ADMIN /opt/oracle/instantclient_23_26/network/admin
