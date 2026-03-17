# offsec-workstation — NightForge Zsh Configuration
# Azrael Security | ForeverLX

# ========== OPERATOR TERMINAL ==========
~/.config/operator-terminal/operator-init.sh

# ========== ZINIT PLUGIN MANAGER ==========
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# ========== PLUGINS ==========
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light hlissner/zsh-autopair
zinit light zsh-users/zsh-history-substring-search

# ========== OPTIONS ==========
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt CORRECT
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt INTERACTIVE_COMMENTS

# ========== HISTORY ==========
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
HISTORY_IGNORE="(ls|ll|la|cd|pwd|exit|clear|history)"

# ========== COMPLETIONS ==========
autoload -Uz compinit
compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ========== KEY BINDINGS ==========
bindkey -v
export KEYTIMEOUT=1
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
bindkey '^R' history-incremental-search-backward
bindkey '^ ' autosuggest-accept

# ========== ENVIRONMENT ==========
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'
export LESS='-R'
export PATH="$HOME/.local/bin:$PATH"
export DOCKER_HOST=unix:///run/user/1002/podman/podman.sock
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# ========== OFFSEC ==========
export OFFSEC_ENGAGE_ROOT="$HOME/engage"

precmd() {
    if [[ $PWD == $OFFSEC_ENGAGE_ROOT/* ]]; then
        ENGAGEMENT=$(echo $PWD | sed "s|$OFFSEC_ENGAGE_ROOT/||" | cut -d'/' -f1)
        export OFFSEC_CURRENT_ENGAGEMENT="$ENGAGEMENT"
    else
        unset OFFSEC_CURRENT_ENGAGEMENT
    fi
}

# ========== FUNCTIONS ==========
c() {
    case "$1" in
        ad|re|web|toolbox)
            ~/Github/offsec-workstation/modules/container/scripts/container.sh run "$1"
            ;;
        *)
            echo "Usage: c [ad|re|web|toolbox]"
            ;;
    esac
}

mkcd() { mkdir -p "$1" && cd "$1" }

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.rar)     unrar x "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.tbz2)    tar xjf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.Z)       uncompress "$1" ;;
            *.7z)      7z x "$1" ;;
            *)         echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

mitre_log() {
    MITRE_LOG="$PWD/mitre.log"
    case "$1" in
        log)
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $2 - $3" >> "$MITRE_LOG"
            echo "✓ Logged: $2 - $3"
            ;;
        view)
            [[ -f "$MITRE_LOG" ]] && cat "$MITRE_LOG" || echo "No MITRE log found"
            ;;
        *)
            echo "Usage: mitre log T1059.001 'PowerShell execution'"
            echo "       mitre view"
            ;;
    esac
}

# ========== ALIASES ==========
[[ -f ~/.config/zsh/aliases.zsh ]] && source ~/.config/zsh/aliases.zsh

# ========== STARSHIP ==========
eval "$(starship init zsh)"
