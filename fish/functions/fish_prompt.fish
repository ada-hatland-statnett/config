function fish_prompt
    # Colors
    set -l c_user (set_color brred)
    set -l c_path (set_color brgreen)
    set -l c_norm (set_color normal)

    # Username
    set -l user (whoami)

    # Last 2 directories of $PWD
    set -l trimmed (string trim -c / -- "$PWD")
    set -l parts
    if test -n "$trimmed"
        set parts (string split / -- "$trimmed")
    else
        set parts
    end

    set -l n (count $parts)
    set -l tail2 ""

    if test $n -eq 0
        set tail2 "/"
    else if test $n -eq 1
        set tail2 $parts[1]
    else
        set -l i (math $n - 1)
        set tail2 "$parts[$i]/$parts[$n]"
    end

    # Output: user:dir1/dir2$
    echo -n $c_user$user
    echo -n $c_norm":"
    echo -n $c_path$tail2
    echo -n $c_norm"\$ "
end
