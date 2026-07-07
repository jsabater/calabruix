---
title: "Configuring Zsh on a new laptop for DevOps"
date: 2026-07-07
lastmod: 2026-07-07
description: "A reproducible walkthrough of setting up Zsh with Oh My Zsh, fzf, Starship, and zsh-patina on a fresh Linux installation."
summary: "How to configure the Z shell with Oh My Zsh, fzf, Starship, and zsh-patina on Linux."
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


### Plug-ins

To see what an actual *Oh My Zsh* plug-in looks like in practice, consider [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions). As you type, it suggests the rest of a command in dim grey text, based on your history and completions. You can accept the suggestion with the right arrow key, or ignore it and keep typing. It is a small feature, but one you will miss immediately if you switch back to a shell without it.

Installing it means cloning it into Oh My Zsh's custom plug-ins directory:

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

And then listing it as an active plug-in in `~/.zshrc`:

```zsh
# Do not add `zsh-syntax-highlighting` or `fast-syntax-highlighting`
# since we are using `zsh-patina`
plugins=(colored-man-pages git zsh-autosuggestions)
```

Plugins that ship with *Oh My Zsh* by default, as opposed to ones you install yourself, like `zsh-autosuggestions`, live under `~/.oh-my-zsh/plugins`, and can be enabled just by adding their name to the `plugins` array. For instance, we took the chance to also enable the `colored-man-pages` plug-in, which adds colour to the manual pages, e.g., `man wget`.


## Complementary tools

The rest of the setup is not done via Oh My Zsh plug-ins, but via standalone binaries, hooked into Zsh through a shell activation line rather than the `plugins=()` array.


### fzf

[fzf](https://github.com/junegunn/fzf) is a general-purpose fuzzy finder for the command line. Once wired into Zsh, it upgrades reverse history search (`Ctrl + R`) into an interactive fuzzy search, and adds fuzzy file and directory completion. I install it as a pinned binary release rather than through the distribution's package manager, so the version is explicit and reproducible:

```bash
FZF_VERSION="0.73.1"
wget "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
  -O /tmp/fzf.tar.gz
tar -xzf /tmp/fzf.tar.gz -C ~/.local/bin fzf
chmod +x ~/.local/bin/fzf
rm /tmp/fzf.tar.gz
```

Enabling it in Zsh is a single line:

```bash
echo 'source <(fzf --zsh)' >> ~/.zshrc
```


### FiraCode Nerd Font

Both Starship and several Oh My Zsh themes rely on glyphs, e.g., Git branch icons, language logos, status symbols, that live outside the standard Unicode ranges most fonts ship with. [Nerd Fonts](https://www.nerdfonts.com/) solves this by patching popular programming fonts with these extra icon sets. I use FiraCode, just because it is the default suggestion at the Starship website and it does the job just fine:

```bash
NERD_FONT_VERSION="3.4.0"
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/FiraCode.zip \
  -O /tmp/FiraCode.zip
mkdir -p ~/.local/share/fonts/FiraCode
unzip /tmp/FiraCode.zip -d ~/.local/share/fonts/FiraCode
fc-cache -fv
rm /tmp/FiraCode.zip
```

Without this step, Starship's prompt will still work, but you will see empty boxes or question marks where icons should be.

### Starship

[Starship](https://starship.rs/) is a minimal, extremely fast prompt that works identically across Bash, Zsh, Fish, and other shells. You get a prompt that adapts to context automatically, showing the current Git branch and status, detected language runtimes and their versions, and more, only when relevant. For example, here is what it looks like inside a Python repository with a virtual environment active:

```zsh
Projects/myrepo is 󰏗 v0.1.0 via  v3.14.6 (myrepo)
```

Installing it is a single script, same as Oh My Zsh:

```bash
curl -sS https://starship.rs/install.sh | sh
```

> You can install `curl` using `apt install --yes curl`.

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
ZSH_PATINA_VERSION="1.8.0"
wget https://github.com/michel-kraemer/zsh-patina/releases/download/${ZSH_PATINA_VERSION}/zsh-patina_${ZSH_PATINA_VERSION}_amd64.deb \
  --output-document /tmp/zsh-patina_${ZSH_PATINA_VERSION}_amd64.deb
sudo dpkg --install /tmp/zsh-patina_${ZSH_PATINA_VERSION}_amd64.deb
rm /tmp/zsh-patina_${ZSH_PATINA_VERSION}_amd64.deb
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

You may have noticed that all three activation lines above use `source <(command)` rather than the more commonly documented `eval "$(command)"`. Both achieve the same result, i.e., running the shell code a tool generates on startup, but I avoid `eval` deliberately.

`eval` executes a string as shell code with no separation between "data" and "instructions," which is exactly the kind of pattern that makes shell injection possible if the generated output is ever tampered with or unexpectedly malformed. `source <(...)` runs the same generated code, but as an actual script read through process substitution, which I find both safer as a habit and easier to inspect.

> You can run the inner command on its own and see exactly what it would output before sourcing it.

## Order of activation

There is one detail that is easy to get wrong: order of activation in `~/.zshrc`. If you followed the instructions above in order, since each `echo ... >> ~/.zshrc` command appends to the end of the file, and Oh My Zsh's own `plugins=()` array and `source $ZSH/oh-my-zsh.sh` line are set up earlier in the file, the ordering ends up being:

1. Oh My Zsh loads first, with its plugins (`zsh-autosuggestions`, in this case).
2. Starship's `init` is sourced next.
3. `zsh-patina`'s activation is sourced last.

This is not incidental. Both Starship and `zsh-patina` hook into Zsh's prompt and command-execution machinery, i.e., the `precmd`/`preexec` hooks that run before and after each command. Sourcing them at the very end of the file means they wrap around whatever *Oh My Zsh* and its plugins have already defined, rather than risk being overridden by something loaded afterwards.

So, if you ever restructure your `~/.zshrc`, keep this order. For example, let's say that you install [fnm](https://github.com/Schniz/fnm) for a *Node.js* project and want to integrate it with Zsh, the last lines of your `~/.zshrc` file would look like this:

```zsh
source <(fnm env --use-on-cd --shell zsh)
source <(fzf --zsh)
source <(starship init zsh)
source <(zsh-patina activate)
```


### Validating the setup

Once everything above has run, start a new session and walk through a short checklist to confirm each piece actually works:

```bash
zsh
getent passwd $USER | cut -d: -f7
zsh-patina check
fc-list : family | grep -i "FiraCode"
starship --version
```

Where:

- `getent passwd ...` should print the path to Zsh, confirming the default shell change took effect.
- `zsh-patina check` runs the tool's own self-diagnostic.
- `fc-list ... "FiraCode"` confirms the Nerd Font variant was installed and is registered with fontconfig.
- `starship --version` confirms the binary is on your `PATH` and reachable.

If any of these come back empty or with an error, it is worth checking `~/.zshrc` directly before troubleshooting further, as a surprising number of shell configuration issues turn out to be a typo, or a step run in the wrong order.

Optionally, log out and log back in, then perform the checks.

## Final note

None of these tools are strictly necessary, but the incremental cost of setting each of these up once is small compared to the time saved across months of daily use. I have deliberately kept every install step version-pinned and scripted so that this configuration can be reproduced identically.
