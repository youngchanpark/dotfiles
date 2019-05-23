# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

alias less='less -S'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../../'
alias sl='ls'
alias ks='ls'
alias l='ls'
alias jl='jupyter notebook list'
alias j='jobs' 
alias ll='ls -lh'
alias ta='tmux a -t'
alias tl='tmux ls'
alias tst='timestamp=$(date +"%Y%m%d") ; echo timestamp=\$\(date +\"%Y%m%d\"\)'
alias sbrc='source ~/.bashrc ; echo "~/.bashrc sourced"'

PATH=$PATH:$HOME/.local/bin:$HOME/bin
PATH=$PATH:$HOME/script/bin
export PATH

export LD_LIBRARY_PATH=/data/shared_env/lib64/R/lib:${LD_LIBRARY_PATH}

umask 0027 # u=rwx,g=rx,o=
# umask cannot make u=rwx,g=rx,o=r, which is very irritating.

export PS1="\[\033[38;5;34m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]\n\[$(tput sgr0)\]\[\033[38;5;86m\]\u\[$(tput sgr0)\]\[\033[38;5;196m\]@\[$(tput sgr0)\]\[\033[38;5;123m\]\h\[$(tput sgr0)\]\[\033[38;5;196m\]\\$\[$(tput sgr0)\]"

