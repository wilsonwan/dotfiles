if status is-interactive
    # Commands to run in interactive sessions can go here
end

export PATH="$HOME/.local/bin:$PATH"

# startship
if command -q starship
    source (starship init fish --print-full-init | psub)
end