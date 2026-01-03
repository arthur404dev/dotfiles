if status is-interactive
    # Commands to run in interactive sessions can go here
    set fish_greeting
end

set -gx EDITOR nvim
starship init fish | source

fish_ssh_agent
fish_vi_key_bindings
fish_add_path $HOME/.local/bin

for f in ~/.config/fish/config/*.fish
    source $f
end
