---
title: "Configuring Zsh on a new laptop for DevOps"
date: 2026-07-07
lastmod: 2026-09-04
description: "A reproducible walkthrough of setting up Zsh with Oh My Zsh, fzf, deja, Starship, and zsh-patina on a fresh Linux installation."
summary: "How to configure the Z shell with Oh My Zsh, fzf, deja, Starship, and zsh-patina on Linux."
categories: ["infrastructure"]
tags: ["terminal", "shell"]
---

The shell is one of the most important tools a systems engineer works with. It is the interface you use the most when your day is spent moving between servers, containers, and repositories. This article walks through how I configured Zsh on my new laptop, with every step reproducible and version-pinned, the way I try to document all of my infrastructure work.


## Origins

Zsh (the "Z shell") was created by Paul Falstad in 1990, originally as a student project at Princeton University. Its name is, appropriately, a small joke: it was meant to be the alphabetically last word on shells. Over the following decades it grew into something considerably more ambitious than a class assignment, borrowing ideas from `ksh`, `bash`, and `tcsh` while adding its own extensive completion system, scripting features, and configurability.

While Zsh has been the default login shell on macOS since Catalina (2019), Bash is still the default in most Linux distributions.


## Why Zsh

Bash is everywhere, and for portable scripts it is still the default choice (or plain `sh`) without hesitation. But as an *interactive* daily driver, Zsh offers a handful of features that make a real difference:

- **A far more capable completion system.** Zsh's `compinit`/`compdef` framework can complete not just filenames, but subcommands, flags, and context-aware arguments for tools that ship completion definitions.
- **Better globbing.** Extended glob patterns and recursive globbing (`**/*.py`, for instance) work out of the box.
- **Shared, persistent history across sessions.** Multiple open terminals can share history in real time.
- **Richer prompt scripting.** Small conveniences, but noticeable.
- **A mature plugin ecosystem.** Frameworks like *Oh My Zsh* exist specifically because Zsh's extensibility invites this kind of layering.


## Installation

The first step is simply getting Zsh installed and set as the default login shell:

```bash
sudo apt install --yes zsh
```

Before switching, it is worth confirming that Zsh is listed among the shells the system considers valid login shells:

```bash
grep zsh /etc/shells
```

With that confirmed, set it as the default shell for the current user:

```bash
chsh -s $(which zsh)
```

`chsh` only takes effect on your next login, so to make sure it worked:

```bash
getent passwd $USER | cut -d: -f7
```


## Oh My Zsh

*Oh My Zsh* is a community-maintained framework that sits on top of Zsh, providing a plugin manager, a large library of themes, and sane defaults for things you would otherwise have to configure by hand, e.g., completion styles, history behaviour, and so on. Its real value is the plugin ecosystem: hundreds of community-contributed plugins that wrap common tools with useful completions and aliases, all toggled through a single array in your configuration file.

Installing it is a single script:

```bash
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
exec zsh
```


## Plug-ins

A plug-in is Zsh code, executing inside the shell process, typically aliases, functions, completion definitions, ZLE (Z-shell Line Editor) widgets, key bindings and environment variables. Plug-ins bundled with the framework are located under `~/.oh-my-zsh/plugins/`, whereas custom plug-ins are located under `~/.oh-my-zsh/custom/plugins/`. They are named in the `plugins=()` array in the `~/.zshrc` configuration file.

Separate programs can add functionality to Zsh without being plug-ins. A binary that emits Zsh code on request, for instance, is activated by sourcing that code from `~/.zshrc`, e.g., `source <(tool init zsh)`, and knows nothing about *Oh My Zsh* (it behaves identically on a bare Zsh installation). Other dependencies are not code at all: a font is simply a font, however much a prompt may rely on it.

The three plug-ins below all ship with *Oh My Zsh*, so enabling them is just a matter of naming them in the array. A custom plug-in works the same way once its directory exists under `~/.oh-my-zsh/custom/plugins/`. The only extra step is putting it there, usually with a `git clone`.

```zsh
plugins=(colored-man-pages git ufw)
```

By default, *Oh My Zsh* enables the `git` plug-in, which provides many aliases (e.g., `ga` equals `git add`) and a few useful functions (e.g., `gbds` deletes all squash-merged branches) for *Git*. We are adding the *Colored man pages plugin*, which adds colours to man pages (e.g., `man grep`) and the *UFW plugin*, which adds completion for managing the Uncomplicated Firewall (e.g., `sudo ufw status`).

These plug-ins will be active when we start a new shell.

> Do not add `zsh-syntax-highlighting` or `fast-syntax-highlighting` to the `plugins=()` array, as we will be using `zsh-patina`.


## Complementary tools

The rest of the setup does not go through *Oh My Zsh* at all. These are standalone, third-party tools: binaries hooked into Zsh through an activation line in `~/.zshrc` rather than the `plugins=()` array, plus one font that several of them depend on to render their icons.


### fzf

[fzf](https://github.com/junegunn/fzf) is a general-purpose fuzzy finder for the command line. Once wired into Zsh, it upgrades reverse history search (`Ctrl + R`) into an interactive fuzzy search, and adds fuzzy file and directory completion. I install it as a pinned binary release rather than through the distribution's package manager, so the version is explicit and reproducible:

```bash
FZF_VERSION="0.74.3"
wget "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
  --output-document=/tmp/fzf.tar.gz
tar -xzf /tmp/fzf.tar.gz -C ~/.local/bin fzf
chmod +x ~/.local/bin/fzf
rm /tmp/fzf.tar.gz
```

Check the installed version:

```bash
fzf --version
```

Enabling it in Zsh is a single line:

```bash
echo 'source <(fzf --zsh)' >> ~/.zshrc
```


### Deja

[Deja](https://github.com/Giammarco-Ferranti/deja) is a replacement for `zsh-autosuggestions`. Both draw an inline ghost-text suggestion after the cursor, and both accept it with the right arrow key, but the model behind the suggestion is different. `zsh-autosuggestions` can only ever complete a command that starts with what you have typed, while Deja scores candidates on four signals combined: a fuzzy subsequence match, frecency (frequency blended with a one-week recency decay), how often you have run that command from the directory you are currently in, and the probability that it follows the command you just ran.

In practice that last pair is what makes the difference. Typing `dc` in one repository suggests that repository's `docker compose` invocation, but the same two letters in another suggests a different one. Another example would be knowing that you are about to run `just test` after running `just build`.

It runs as a background daemon shared across sessions, keeping the per-keystroke response under a millisecond, and all state lives in a local SQLite database (nothing leaves the machine). It ships as a Go binary, which we will install following these commands:

```bash
DEJA_VERSION="0.4.1"
wget "https://github.com/Giammarco-Ferranti/deja/releases/download/v${DEJA_VERSION}/deja_${DEJA_VERSION}_linux_amd64.tar.gz" \
  --output-document=/tmp/deja.tar.gz
tar -xzf /tmp/deja.tar.gz -C ~/.local/bin deja
chmod +x ~/.local/bin/deja
rm /tmp/deja.tar.gz
```

Check the installed version:

```bash
deja --version
```

Seed the database from your existing history, so it is useful from the first prompt:

```bash
deja import
```

Enabling it in Zsh is a single line:

```bash
echo 'source <(deja init zsh)' >> ~/.zshrc
```

By default, *Deja* binds `Tab` to an inline picker that cycles through ranked alternatives, but `Tab` is already driving `compinit` completion system (a large part of why we chose Zsh over Bash) and it is *fzf*'s fuzzy-completion trigger (`**` followed by `Tab`) as well.

We can keep the default and live with `Tab` doing double duty, as Deja only intercepts it when a suggestion is on screen. However, if we are not comfortable with the `Tab` key having two different meanings depending on an invisible state, we can move the picker onto something else and leave `Tab` entirely to completion. A couple of options are:

1. `Ctrl + N`, the one suggested by the Deja documentation, though it is normally bound to `down-line-or-history` (check with `bindkey | grep '\^N'`).
2. `Alt + N`, normally bound to `history-search-forward` (check with `bindkey | grep '\^\[n'`).

Both are already taken, but neither loss hurts much in this particular setup: both walk forward through history, and between *fzf*'s `Ctrl + R` and *Deja*'s own suggestions we have better ways of getting a past command back.

> You need to be in a Zsh shell to use `bindkey`.

To do this, we need to manually edit our `~/.zshrc` file and, before the `source <(deja init zsh)` instruction, add an export:

```zsh
# Use Ctrl + N to cycle through ranked alternatives
export DEJA_CYCLE_KEY='^N'
source <(deja init zsh)
```

To use `Alt + N`, substitute `'^N'` for `'^[n'`:

```zsh
# Use Alt + N to cycle through ranked alternatives
export DEJA_CYCLE_KEY='^[n'
source <(deja init zsh)
```

> You can obtain the code for a key to your liking by using `cat -v` and typing the combination you want to try. Exit using `Ctrl + C`.

On a fresh prompt, before we have typed anything, *Deja* already predicts the command we are most likely to run next and shows it as ghost text:

- `→` accepts the whole suggestion, `Ctrl + →` accepts one word. The ghost is not part of the line: Enter runs whatever we have actually typed, which on an empty prompt is nothing at all. → is what commits the suggestion into the buffer first.
- `Ctrl + X` suppresses suggestions for the rest of the session.
- `Shift + →` and `Shift + ←` cycle the fuzzy matcher between `tight`, `smart` (the default), and `loose`, controlling how far apart your typed characters are allowed to sprawl in a candidate. `deja fuzzy` shows the current setting.

> If we would rather have a quiet empty prompt, `deja empty off` turns that behaviour off.

A note on secrets. *Deja* records the commands we run into a plaintext SQLite database at `~/.local/share/deja/deja.db`. The directory is `0700` and the files `0600`, but it is not encrypted. It honours the same rules Zsh uses to decide what not to remember. With `setopt hist_ignore_space`, a line starting with a space is discarded by both. `HISTORY_IGNORE` patterns are applied the same way Zsh applies them:

```zsh
setopt hist_ignore_space
HISTORY_IGNORE='(*AWS_SECRET*|*--password*|*TOKEN=*)'
```

*Deja* does not redact secrets embedded in otherwise ordinary commands, e.g., `curl -H "Authorization: ..."`, so the leading space remains the reliable habit. Note also that an ignored command breaks the prediction chain (it is dropped as the "previous command" for sequence scoring, so it cannot resurface indirectly).


### FiraCode Nerd Font

Both *Starship* and several *Oh My Zsh* themes rely on glyphs, e.g., Git branch icons, language logos, status symbols, that live outside the standard Unicode ranges most fonts ship with. [Nerd Fonts](https://www.nerdfonts.com/) solves this by patching popular programming fonts with these extra icon sets. I use FiraCode, just because it is the default suggestion at the Starship website and it does the job just fine:

```bash
NERD_FONT_VERSION="3.5.0"
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/FiraCode.zip \
  ---output-document=/tmp/FiraCode.zip
mkdir -p ~/.local/share/fonts/FiraCode
unzip /tmp/FiraCode.zip -d ~/.local/share/fonts/FiraCode
fc-cache -fv
rm /tmp/FiraCode.zip
```

Without this step, Starship's prompt will still work, but you will see empty boxes or question marks where icons should be.

### Starship

[Starship](https://starship.rs/) is a minimal, extremely fast prompt that works identically across Bash, Zsh, Fish, and other shells. You get a prompt that adapts to context automatically, showing the current Git branch and status, detected language runtimes and their versions, and more, only when relevant. For example, here is what it looks like inside a Python repository with a virtual environment active:

```zsh
Projects/myrepo is 󰏗 v0.3.1 via  v3.14.7 (myrepo)
```

Installing it is a single script, same as Oh My Zsh:

```bash
curl -sS https://starship.rs/install.sh | sh
```

> You can install `curl` using `apt install --yes curl`.

Check the installed version:

```bash
starship --version
```

Starship ships with configuration presets, and since we have already installed a Nerd Font, it makes sense to use the preset built around it:

```bash
mkdir -p ~/.config
starship preset nerd-font-symbols -o ~/.config/starship.toml
```

Then, enable it in Zsh:

```zsh
echo 'source <(starship init zsh)' >> ~/.zshrc
```

### zsh-patina

[zsh-patina](https://github.com/michel-kraemer/zsh-patina) is a syntax highlighter, i.e., the same as `zsh-syntax-highlighting` or `fast-syntax-highlighting`, but implemented differently: it runs as a small background daemon, shared across your open Zsh sessions, and highlights commands, files, and directories based on whether they actually exist and are accessible, rather than through pattern matching alone.

It ships as a `.deb` package rather than a Zsh plugin:

```bash
ZSH_PATINA_VERSION="1.10.0"
wget https://github.com/michel-kraemer/zsh-patina/releases/download/${ZSH_PATINA_VERSION}/zsh-patina_${ZSH_PATINA_VERSION}_amd64.deb \
  --output-document=/tmp/zsh-patina_${ZSH_PATINA_VERSION}_amd64.deb
sudo dpkg --install /tmp/zsh-patina_${ZSH_PATINA_VERSION}_amd64.deb
rm /tmp/zsh-patina_${ZSH_PATINA_VERSION}_amd64.deb
```

Check the installed version:

```bash
zsh-patina --version
```

After installation, enable it in Zsh:

```bash
echo 'source <(zsh-patina activate)' >> ~/.zshrc
```

It is also worth enabling shell completions for the tool itself:

```bash
zsh-patina completion \
  | sudo tee /usr/local/share/zsh/site-functions/_zsh-patina \
  > /dev/null
```

### About using `source`

You may have noticed that all activation lines above use `source <(command)` rather than the more commonly documented `eval "$(command)"`. Both achieve the same result, i.e., running the shell code a tool generates on startup, but I avoid `eval` deliberately.

`eval` executes a string as shell code with no separation between "data" and "instructions," which is exactly the kind of pattern that makes shell injection possible if the generated output is ever tampered with or unexpectedly malformed. `source <(...)` runs the same generated code, but as an actual script read through process substitution, which I find both safer as a habit and easier to inspect.

> You can run the inner command on its own and see exactly what it would output before sourcing it.

## Order of activation

There is one detail that is easy to get wrong: order of activation in `~/.zshrc`. If you followed the instructions above in order, since each `echo ... >> ~/.zshrc` command appends to the end of the file, and *Oh My Zsh*'s own `plugins=()` array and `source $ZSH/oh-my-zsh.sh` line are set up earlier in the file, the ordering ends up being:

1. *Oh My Zsh* loads first, with its plugins.
2. *fzf*'s key bindings and completion are sourced.
3. *Deja*'s integration is sourced, preceded by its key-binding override (optional).
4. Starship's `init` is sourced next.
5. *zsh-patina*'s activation is sourced last.

This is not incidental, though the reason differs per tool. Both *Starship* and *zsh-patina* hook into Zsh's prompt and command-execution machinery, i.e., the `precmd` and `preexec` hooks that run before and after each command. Sourcing them at the very end of the file means they wrap around whatever *Oh My Zsh* and its plugins have already defined, rather than risk being overridden by something loaded afterwards. *Deja* is a different case: it wraps ZLE widgets and key bindings rather than prompt hooks, so it needs *Oh My Zsh* and *fzf* to have finished installing theirs, but it must come before the two prompt tools so they still get the last word.

So, if you ever restructure your `~/.zshrc`, keep this order. For example, let's say that you install [fnm](https://github.com/Schniz/fnm) for a *Node.js* project and want to integrate it with Zsh, the last lines of your `~/.zshrc` file would look like this:

```zsh
source <(fnm env --use-on-cd --shell zsh)
source <(fzf --zsh)
source <(deja init zsh)
source <(starship init zsh)
source <(zsh-patina activate)
```

> If you decided to use some other keybinding to cycle through ranked alternatives instead of `Tab`, you will have the extra `export` line.


## Validating the setup

Once everything above has run, start a new session and walk through a short checklist to confirm each piece actually works:

```bash
zsh
getent passwd $USER | cut -d: -f7
deja ping
zsh-patina check
fc-list : family | grep -i "FiraCode"
starship --version
```

Where:

- `getent passwd ...` should print the path to Zsh, confirming the default shell change took effect.
- `deja ping` should print `pong`.
- `zsh-patina check` runs the tool's own self-diagnostic.
- `fc-list ... "FiraCode"` confirms the Nerd Font variant was installed and is registered with fontconfig.
- `starship --version` confirms the binary is on your `PATH` and reachable.

If any of these come back empty or with an error, it is worth checking `~/.zshrc` directly before troubleshooting further, as a surprising number of shell configuration issues turn out to be a typo, or a step run in the wrong order.

Optionally, log out and log back in, then perform the checks.

## Final note

None of these tools are strictly necessary, but the incremental cost of setting each of these up once is small compared to the time saved across months of daily use. I have deliberately kept every install step version-pinned and scripted so that this configuration can be reproduced identically.
