#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# # Add Zathura-Pywal to path
# export PATH="$BINPATH:\$PATH"

# Add uv and rust apps to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Add quarto path
# export PATH="$HOME/.local/bin:$PATH"
