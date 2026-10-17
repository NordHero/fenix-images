command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

if [[ $- == *i* ]] && grep -qs 'mise=untrusted' "$HOME/.provisioned/status"; then
  echo "mise.toml not trusted; tools not installed. Review ~/mise.toml, then run: mise trust ~/mise.toml && provision.sh"
fi
