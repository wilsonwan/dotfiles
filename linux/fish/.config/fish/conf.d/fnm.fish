# fnm
if set -q XDG_DATA_HOME
  set FNM_PATH "$XDG_DATA_HOME/fnm"
else
  set FNM_PATH "$HOME/.local/share/fnm"
end

if [ -d "$FNM_PATH" ]
  set PATH "$FNM_PATH" $PATH
  fnm env --use-on-cd --shell fish | source
end
