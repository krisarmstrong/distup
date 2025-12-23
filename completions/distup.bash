# Bash completion for distup
# Place in /etc/bash_completion.d/ or source directly

_distup() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Global options
    opts="--help --version --dry-run --list --detect"

    case "${prev}" in
        distup)
            COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
            return 0
            ;;
        *)
            COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
            return 0
            ;;
    esac
}

_upgrade_ubuntu() {
    local cur prev opts modes
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help --version --dry-run"
    modes="lts release"

    COMPREPLY=( $(compgen -W "${opts} ${modes}" -- "${cur}") )
    return 0
}

_upgrade_debian() {
    local cur prev opts modes
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help --version --dry-run"
    modes="stable testing sid"

    COMPREPLY=( $(compgen -W "${opts} ${modes}" -- "${cur}") )
    return 0
}

_upgrade_fedora() {
    local cur prev opts modes
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help --version --dry-run"
    modes="stable rawhide"

    COMPREPLY=( $(compgen -W "${opts} ${modes}" -- "${cur}") )
    return 0
}

_upgrade_arch() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help --version --dry-run --refresh --clean"

    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
}

_upgrade_alpine() {
    local cur prev opts modes
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help --version --dry-run"
    modes="stable edge"

    COMPREPLY=( $(compgen -W "${opts} ${modes}" -- "${cur}") )
    return 0
}

_upgrade_kali() {
    local cur prev opts modes
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help --version --dry-run"
    modes="rolling bleeding-edge"

    COMPREPLY=( $(compgen -W "${opts} ${modes}" -- "${cur}") )
    return 0
}

_upgrade_opensuse() {
    local cur prev opts modes
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help --version --dry-run"
    modes="leap tumbleweed"

    COMPREPLY=( $(compgen -W "${opts} ${modes}" -- "${cur}") )
    return 0
}

_upgrade_rhel_clone() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help --version --dry-run --check --upgrade"

    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
}

# Register completions
complete -F _distup distup
complete -F _upgrade_ubuntu upgrade-ubuntu.sh
complete -F _upgrade_debian upgrade-debian.sh
complete -F _upgrade_fedora upgrade-fedora.sh
complete -F _upgrade_arch upgrade-arch.sh
complete -F _upgrade_alpine upgrade-alpine.sh
complete -F _upgrade_kali upgrade-kali.sh
complete -F _upgrade_opensuse upgrade-opensuse.sh
complete -F _upgrade_rhel_clone upgrade-rhel-clone.sh
