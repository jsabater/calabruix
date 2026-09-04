---
title: "Find in text files using fuzzy search with fif"
date: 2026-09-04
lastmod: 2026-09-04
description: "Installing and configuring fif, a fuzzy find-in-files tool built on fzf, ripgrep and bat, with a live syntax-highlighted preview."
summary: "fif turns fzf, ripgrep and bat into a single fuzzy search-inside-files tool with an instant, highlighted preview of every match."
categories: ["infrastructure"]
tags: ["terminal", "shell"]
---

[fif](https://github.com/roosta/fif), an acronym for "Find In Files", is a small Zsh utility that turns a search for text into something genuinely interactive. Instead of running `grep` or `rg` (*ripgrep*) and reading a wall of matched lines, `fif` hands every match to `fzf` for fuzzy filtering and shows a live, syntax-highlighted preview of the surrounding context as the list narrows down.

It is a thin layer gluing together tools that are very useful on their own and likely already installed: `fzf` drives the fuzzy list, `ripgrep` does the actual text search, and `bat` renders the preview pane with syntax highlighting instead of a flat wall of text.


## Requirements

*fif* needs three things to behave the way this article describes:

1. [fzf](https://github.com/junegunn/fzf), a general-purpose command-line fuzzy finder. Point it at any list (files, shell history, running processes, git branches) and it turns that list into an interactive, narrow-as-you-type interface. It has no idea what text search even is, it only filters and displays whatever it is given. Inside `fif`, `fzf` is the actual interface: every match `rg` finds gets piped into `fzf`'s fuzzy list, and `fzf`'s own preview-window mechanism is what `fif` hooks into to show the syntax-highlighted context alongside the results.

2. [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) is a line-oriented text-search tool, functionally in the same space as [GNU Grep](https://www.gnu.org/software/grep/) (`grep`) or [Silver Searcher](https://github.com/ggreer/the_silver_searcher) (`ag`), built for speed and for automatically respecting `.gitignore`, `.ignore`, and hidden-file conventions without being told to. Inside `fif`, `rg` is what actually performs the text search: it produces the list of matching lines fed into `fzf`. Its speed keeps the fuzzy list responsive even across a large tree, and its `.gitignore`-awareness is what keeps irrelevant directories (e.g., a virtual environment, a build output) out of the results with no manual exclusion needed.

3. [bat](https://github.com/sharkdp/bat) is a `cat` replacement with syntax highlighting, a Git-aware modifications gutter, and line numbers, built on the same syntax-definition library used by a number of editors. Inside `fif`, `bat` is what renders the preview pane, where each match is shown in context with the file's actual syntax highlighted, which is what makes it possible to tell a variable definition from a comment or a template reference at a glance.


### Debian packages

Install `rg` and `bat` from the Debian repositories:

```bash
sudo apt install --yes bat fzf ripgrep
```

One thing worth knowing before moving on. Debian renames the `bat` executable to `batcat`, because the name `bat` was already taken by an unrelated package. Since `fif` looks for a binary literally named `bat` to decide whether to use it for the preview pane, we will fix it with a symlink:

```bash
mkdir --parents ~/.local/bin
ln --symbolic /usr/bin/batcat ~/.local/bin/bat
```

As long as `~/.local/bin` comes before `/usr/bin` in `$PATH`, `bat` resolves correctly from then on for `fif`, and for anything else that expects the upstream binary name.

Check the installed versions with the following commands:

```bash
bat --version
fzf --version
rg --version
```


### Binaries

Debian's own packages trade newness for stability: whatever version lands in a release stays there, tested and frozen, for the lifetime of that release, which is exactly why `sudo apt install` above is the sensible default for most setups. For anyone who specifically wants the latest upstream release instead, both projects publish prebuilt, statically-linked binaries on their GitHub releases pages, making a pinned install into `~/.local/bin` a clean alternative.

> This replaces the `apt install`/symlink route above, rather than sitting alongside it.

*bat*, from the [releases page](https://github.com/sharkdp/bat/releases/latest):

```bash
BAT_VERSION="v0.26.1"
wget "https://github.com/sharkdp/bat/releases/download/${BAT_VERSION}/bat-${BAT_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
  --output-document=/tmp/bat.tar.gz
tar -xzf /tmp/bat.tar.gz -C ~/.local/bin --strip-components=1 "bat-${BAT_VERSION}-x86_64-unknown-linux-musl/bat"
chmod +x ~/.local/bin/bat
rm /tmp/bat.tar.gz
```

No `batcat` symlink needed on this route (the binary is already named `bat`).

*fzf*, from the [releases page](https://github.com/junegunn/fzf/releases/latest):

```bash
FZF_VERSION="0.74.3"
wget "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
  --output-document=/tmp/fzf.tar.gz
tar -xzf /tmp/fzf.tar.gz -C ~/.local/bin fzf
chmod +x ~/.local/bin/fzf
rm /tmp/fzf.tar.gz
```

*ripgrep*, from the [releases page](https://github.com/BurntSushi/ripgrep/releases/latest):

```bash
RG_VERSION="15.2.0"
wget "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
  --output-document=/tmp/ripgrep.tar.gz
tar -xzf /tmp/ripgrep.tar.gz -C ~/.local/bin --strip-components=1 "ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl/rg"
chmod +x ~/.local/bin/rg
rm /tmp/ripgrep.tar.gz
```

Check the installed versions with the following commands:

```bash
bat --version
fzf --version
rg --version
```


## Installation

Clone the repository into *Oh My Zsh*'s custom plugins directory:

```bash
git clone https://github.com/roosta/fif ~/.oh-my-zsh/custom/plugins/fif
```

Then add `fif` to the `plugins` array in `~/.zshrc`:

```zsh
plugins=(colored-man-pages fif git ufw)
```

*Oh My Zsh*'s plugin loader automatically sources any file named `<plugin-name>.plugin.zsh` it finds in that directory (the repository already ships one, `fif.plugin.zsh`, matching the folder name exactly). No manual `source` line needed.

Reload the shell, or open a new terminal, and `fif` is available. There is no `--version` flag in `fif`, but we can check the version  with the following command instead:

```bash
echo $_FIF_VERSION
```

## Configuration

`fif` exposes more environment variables than most people will ever need. Three are worth setting deliberately:

| Variable            | Purpose                                                                                                |
|---------------------|--------------------------------------------------------------------------------------------------------|
| `FIF_RG_OPTS`       | Options passed to `rg` for the concatenation step (colours, hidden files, and so on)                   |
| `FIF_FZF_OPTS`      | Options layered on top of `$FZF_DEFAULT_OPTS` for the fuzzy list itself                                |
| `FIF_EDITOR_SCRIPT` | Points at a script to open the matched file/line in something other than `$EDITOR`'s default behaviour |

Since `fif` now loads through *Oh My Zsh*'s `plugins` array, these need to be set **before** `source $ZSH/oh-my-zsh.sh` (that line is what actually sources `fif.plugin.zsh`, and it reads these variables at that moment).

Add the block just above the `plugins` line:

```zsh
fif_rg_opts=(
  --hidden
  --color always
  --colors=match:none
  --colors=path:fg:blue
  --colors=line:fg:yellow
)

plugins=(colored-man-pages fif git ufw)

source $ZSH/oh-my-zsh.sh
```

`FIF_EDITOR_SCRIPT` is only worth setting if `$EDITOR`'s default behaviour (which already works out of the box with Vim) does not fit what is actually in use. The script receives two arguments, the matched line number and then the file path, so any editor with its own "jump to line" flag can be wired in without touching `fif` itself.

## Usage

Run `fif` with no arguments to search every file from the current directory, or scope it to a specific file or path:

```bash
fif ~/Projects/mywebsite
```

*fif* will scan the directory and present the interface. You can start typing and, whatever you type, it will instantly offer results. These are the default keybinds:

| Keybind  | Action                                     |
|----------|--------------------------------------------|
| `↑`, `↓` | Move the selection up/down the match list  |
| `Enter`  | Confirm and open the file at that location |
| `Ctrl-s` | Toggle sort                                |
| `Ctrl-p` | Toggle the preview pane                    |

> The moment you hit enter, you leave *fif* and enter your default editor, so you need to start using your editor's keybindings.

A set of Python projects, each with its own `.venv/`, is exactly the case `rg`'s `.gitignore`-awareness earns its keep. As long as `.venv/` is listed in `.gitignore` (which it should be) a search across the whole tree never has to wade through a virtual environment's installed packages to reach the actual source files. Typing a fragment of a function name, e.g., `datetime`, filters live across every exercise folder, with each `.venv/` silently excluded. No need to use `--exclude` flags or manual pruning.

Moreover, searching such a codebase for a `django-environ` accessor (e.g., `DATABASE_URL`) is where `bat`'s preview pane earns its place. A flat-text match on that string looks identical whether it turns up in `config/settings.py` as a typed accessor call, in `.env.example` as a plain `KEY=value` line, or in a `compose.yaml` file as a YAML `environment:` entry. `fif`'s preview renders each one in its actual syntax, so it is obvious at a glance which is a Python assignment, which is a shell variable, and which is just sitting in a comment, without opening a single file.

`FIF_EDITOR_SCRIPT` points at a small script that receives two arguments (the matched line number, then the file path) and decides how to open them. Because [VS Codium](https://vscodium.com/)'s `codium` executable understands the `--goto FILE:LINE` syntax, should we want to use it as our editor, the custom script pointing at it is a single line:

```bash
codium --goto "${2}:${1}"
```

To do this, first create somewhere permanent to store the script:

```bash
mkdir --parents ~/.config/zsh/scripts
```

Now create the `codium.sh` script:

```bash
cat > ~/.config/zsh/scripts/fif-codium.sh << 'EOF'
#!/usr/bin/env bash
codium --goto "${2}:${1}"
EOF
```

Then make it executable:

```bash
chmod +x ~/.config/zsh/scripts/fif-codium.sh
```

And point `FIF_EDITOR_SCRIPT` at it in the `~/.zshrc` file, before the `plugins` line, alongside `fif_rg_opts`, so it is read the moment `fif.plugin.zsh` is sourced:

```zsh
export FIF_EDITOR_SCRIPT="$HOME/.config/zsh/scripts/fif-codium.sh"
fif_rg_opts=(
  --hidden
  --color always
  --colors=match:none
  --colors=path:fg:blue
  --colors=line:fg:yellow
)

plugins=(colored-man-pages fif git ufw)
```

With that in place, pressing `Enter` on a match opens that exact file at that exact line in VS Codium.

## Where fif fits

Worth being precise about what `fif` replaces and what it does not. `fzf`'s own `Ctrl-R` binding searches shell *history* (commands already run), whereas `fif` searches file *contents*, an entirely different corpus. And against plain `rg`, `fif` does not do anything `rg` could not already do on its own. What it adds is the fuzzy, interactive narrowing and the live preview, turning a search into something closer to browsing than to reading a static list of matches.

## Finding files

`fif` solves finding text inside files. [fd](https://github.com/sharkdp/fd) solves the adjacent problem: finding files *by name*, fast, with the same `.gitignore`-awareness as `rg` and the same no-flags-needed defaults. Same author as `bat`, same philosophy as `rg`, an excellent companion to `fif`. Installed alongside these, the three cover finding files, finding text, and reading files nicely with no overlap between them:

```bash
sudo apt install --yes fd-find
```

On Debian, the binary is installed as `fdfind`, for the same name-clash reason `bat` becomes `batcat`. The same symlink trick applies:

```bash
ln --symbolic /usr/bin/fdfind ~/.local/bin/fd
```

And as before, we can install the latest binary if we prefer so (and skip the symbolic link):

```bash
FD_VERSION="v10.5.0"
wget "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/fd-${FD_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
  -O /tmp/fd.tar.gz
tar -xzf /tmp/fd.tar.gz -C ~/.local/bin --strip-components=1 "fd-${FD_VERSION}-x86_64-unknown-linux-musl/fd"
chmod +x ~/.local/bin/fd
rm /tmp/fd.tar.gz
```

Check the installed version with the following command:

```bash
fd --version
```

Tying back to the `.venv/` examples already in this article, we can use `fd` to list every `.py` file across our tree of Python projects, with each website or exercise's `.venv/` skipped automatically, the same `.gitignore`-awareness `fif` leans on via `rg`, just applied to finding files by name instead of searching inside them:

```
fd --extension py . ~/Projects/mywebsite
```

The `.` sitting between `--extension py` and the path is doing real work, not decoration. `fd`'s argument order is `fd [PATTERN] [PATH...]`, i.e., the first positional argument is always read as a search pattern, never as a path. Drop the `.` and `fd` would try to treat `~/Projects/mywebsite` itself as the pattern. Since that string contains a `/`, `fd` refuses outright, because a pattern with a path separator can never match a bare filename. `.` sidesteps this by acting as a match-all pattern (as a regular expression it matches any single character, and since every filename has at least one, it matches everything) leaving the `--extension` filter to do the actual narrowing and the path argument free to land where it belongs.
