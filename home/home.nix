{ pkgs, ... }:
{
  home.username = "haaksk";
  home.homeDirectory = "/var/home/haaksk";
  home.stateVersion = "26.05";
  targets.genericLinux.enable = true;
  targets.genericLinux.gpu.enable = false;
  programs.home-manager.enable = true;

  # Home Manager owns packages and session integration; Stow owns personal files.
  home.packages = with pkgs; [
    eza ripgrep zoxide fzf fd bat lazygit neovim uv tmux
    direnv nix-direnv zsh-autosuggestions nerd-fonts.jetbrains-mono
  ];
}
