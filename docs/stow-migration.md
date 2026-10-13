# Personal dotfiles with Stow

Home Manager supplies packages and session integration. Personal Zsh, tmux,
lazygit, direnv, and font configuration belongs in
<https://github.com/HakonSkogsrud/.dotfiles>.

The existing `omarchy/zshrc-home` package contains an Arch-specific plugin path.
For Kinoite, create a separate `kionite` package from the working configuration.
Do this before activating the new package-only Home Manager configuration:

```sh
# Clone the dotfiles repository first if it does not already exist.
git clone https://github.com/HakonSkogsrud/.dotfiles.git ~/.dotfiles
```

If it already exists, use the existing checkout. Back up the currently active
files, then copy them into a new Stow package:

```sh
backup="$HOME/.local/state/kionite/dotfiles-before-stow"
mkdir -p "$backup"
cp -L ~/.zshrc "$backup/zshrc"
cp -L ~/.tmux.conf "$backup/tmux.conf"
cp -L ~/.config/lazygit/config.yml "$backup/lazygit.yml"

test ! -e ~/.dotfiles/kionite
mkdir -p ~/.dotfiles/kionite/.config/{lazygit,direnv,fontconfig/conf.d}
cp "$backup/zshrc" ~/.dotfiles/kionite/.zshrc
cp "$backup/tmux.conf" ~/.dotfiles/kionite/.tmux.conf
cp "$backup/lazygit.yml" ~/.dotfiles/kionite/.config/lazygit/config.yml
```

In the new `.zshrc`, replace both occurrences of the rendered store path to
`zsh-autosuggestions.zsh` with:

```sh
"$HOME/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
```

Keep the existing guarded source of
`$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh`, the builtin-cd fallback,
and the direnv hook. The tmux shell should remain `/usr/bin/zsh`.

Add the nix-direnv integration to
`kionite/.config/direnv/direnvrc`:

```sh
source "$HOME/.nix-profile/share/nix-direnv/direnvrc"
```

Add `kionite/.config/fontconfig/conf.d/10-nix-profile-fonts.conf`:

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>~/.nix-profile/share/fonts</dir>
</fontconfig>
```

Now activate the new Home Manager configuration. It removes its old personal-file
links, while keeping the packages and profile:

```sh
cd ~/kionite/home
nix run .#homeConfigurations.haaksk.activationPackage
```

Use your actual image-repository checkout path. `~/kinoite-shell` is the old
prototype copy; update it before using it, or use the canonical repository.

Then check and apply Stow:

```sh
cd ~/.dotfiles
stow --no-folding --simulate --verbose --target="$HOME" kionite
stow --no-folding --verbose --target="$HOME" kionite
fc-cache -f
```

Resolve reported conflicts before the second command. Do not use `--adopt` to
silently move an existing Home Manager link into the dotfiles repository.
Test a new Zsh terminal, then commit the new `kionite` package in `.dotfiles`.

This migration is intentionally explicit: publishing or booting the new OS image
does not automatically activate Home Manager or rewrite personal dotfiles.
