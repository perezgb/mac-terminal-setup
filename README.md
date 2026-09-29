# Mac Setup

Bootstrap a fresh Mac: Homebrew packages, apps, terminal (iTerm2 + Oh My Zsh +
Powerlevel10k), language runtimes, dotfiles and macOS defaults.

Safe to re-run. Anything already installed is adopted or skipped, never
clobbered — existing dotfiles are backed up to `~/.<name>.backup` first.

## Install

```bash
xcode-select --install          # if you don't already have the CLI tools
git clone https://github.com/perezgb/mac-terminal-setup.git
cd mac-terminal-setup
./setup.sh                      # add --no-macos to skip the system defaults
```

Clone rather than pipe to bash — the script needs `dotfiles/` and `Brewfile`
next to it.

## What it installs

| | |
|---|---|
| CLI | autojump, awscli, bash, cloc, coreutils, ffmpeg, gh, git, git-lfs, uv, whisper.cpp |
| Apps | iTerm2, Cursor, VS Code, GitHub Desktop, Chrome, Google Drive, Slack, Obsidian, Rectangle, Flycut, OBS, Claude, ChatGPT |
| Shell | Oh My Zsh, Powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting |
| Node | nvm → current LTS, plus `aws-cdk` and `defuddle` globally |
| Java | SDKMAN → latest JDK + Gradle |
| Python | uv → latest stable CPython |
| Agents | Claude Code |

Runtimes are installed at whatever is current, never pinned to an old version.

Dotfiles (`dotfiles/zshrc`, `zprofile`, `gitconfig`, `p10k.zsh`) are symlinked
into `$HOME`, so editing them here edits the live config.

## One toolchain per language

Deliberately *not* installed, to keep shell startup fast and PATH unambiguous:
pyenv, Anaconda and poetry (uv covers it), jenv and brew's
openjdk/gradle/maven (SDKMAN owns Java).

## Manual steps afterwards

- `gh auth login`
- Set the iTerm2 font to **MesloLGS NF** (installed by the Brewfile)
- Sign into Chrome, Slack, Google Drive
- Not on Homebrew, download by hand: Antigravity, Antigravity IDE, OpenWhispr,
  ChatGPT Atlas
- Copy secrets from the old machine: `~/.ssh`, `~/.aws`

## Restore

```bash
cp ~/.zshrc.backup ~/.zshrc
cp ~/.p10k.zsh.backup ~/.p10k.zsh
```
