if status is-interactive
# Commands to run in interactive sessions can go here
end
export PATH="$HOME/.local/bin:$PATH"

# opencode
fish_add_path $HOME/.opencode/bin

# startship
starship init fish | source
