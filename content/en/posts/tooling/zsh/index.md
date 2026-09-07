---
title: "Configuring Zsh on a new laptop for DevOps"
date: 2026-07-07
lastmod: 2026-09-07
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
DEJA_VERSION="0.4.2"
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


## Yakuake tab labels

[Yakuake](https://apps.kde.org/yakuake/) is a drop-down terminal emulator for [KDE Plasma](https://kde.org/plasma-desktop/). It embeds the same [Konsole](https://apps.kde.org/konsole/) component the standalone application uses, so profiles, colour schemes and rendering behave identically, but instead of living in a window it slides down from the top of the screen on a global shortcut (`F12` by default) and rolls back up when you are done.

It comes from the distribution repositories, so unlike the tools above there is no version to pin:

```bash
sudo apt install --yes yakuake
```

Like Konsole, it keeps sessions in tabs along the bottom of the panel. Once there are six or seven of them open, the default `Shell` label is of no use at all. Therefore, we want for each tab to label itself: the name of the directory we are sitting in when the shell is idle, e.g., `mywebsite`, and the name of whatever is currently running when it is not, e.g., `mywebsite - just build`.


### The tools for the job

Zsh already has the machinery for this, and so does *Oh My Zsh*. Its `lib/termsupport.zsh` sets both the window title and the tab title on every prompt and every command, formatted through `ZSH_THEME_TERM_TITLE_IDLE` and `ZSH_THEME_TERM_TAB_TITLE_IDLE` and switched off with `DISABLE_AUTO_TITLE`. It does so the way every shell has done for decades: by printing [*](OSC) escape sequences (`\e]2;…\a` for the window, `\e]1;…\a` for the tab) into the terminal and letting the emulator interpret them.

Konsole honours those sequences. Yakuake discards them, so its tab bar never receives anything and Konsole's `%w` tab title format has nothing to show. The only interface Yakuake exposes for tab labels is D-Bus (Desktop Bus).

So the shape of the solution is the same as *Oh My Zsh*'s, but the transport changes. We keep:

- **`add-zsh-hook`**, an autoloadable function shipped with Zsh, to register our code with the `precmd` and `preexec` hooks, i.e., the same two hooks *Starship* and *zsh-patina* use. `precmd` runs before each prompt is drawn (idle) and `preexec` runs after `Enter` but before the command executes (busy).
- **Zsh parameter expansion** to derive the label without spawning any helper processes.

And we replace the `print -Pn "\e]…"` call with a `gdbus` call. Nothing here is a plug-in, so nothing goes into the `plugins=()` array, and there is no new binary to install either: `gdbus` ships with GLib (GTK C utility library), which is already on any Plasma desktop.

> If you prefer Qt's tooling, `qdbus6` takes the same arguments in a shorter form. I use `gdbus` because it is present even on machines where Qt is not.


### How the setup works

Yakuake's D-Bus service is `org.kde.yakuake`, and it exposes two objects we care about: `/yakuake/sessions`, which can tell us which session is currently active, and `/yakuake/tabs`, which can rename a tab given a session id. So, we are going to write a script that goes through three steps:

1. Work out our own session id once.
2. Define a helper that renames it.
3. Hang that helper off the two hooks.

Add the following to `~/.zshrc`:

```zsh
# Yakuake tab labels, set over D-Bus because Yakuake ignores OSC titles
if [[ -n $KONSOLE_DBUS_SESSION ]] && (( $+commands[gdbus] )); then

  typeset -g YAKUAKE_TAB_ID="${${$(gdbus call --session \
    --dest org.kde.yakuake --object-path /yakuake/sessions \
    --method org.kde.yakuake.activeSessionId 2>/dev/null)#\(}%,\)}"

  if [[ $YAKUAKE_TAB_ID == <-> ]]; then

    _yakuake_tab_title() {
      gdbus call --session --dest org.kde.yakuake \
        --object-path /yakuake/tabs \
        --method org.kde.yakuake.setTabTitle \
        "$YAKUAKE_TAB_ID" "$1" > /dev/null 2>&1 &!
    }

    _yakuake_tab_title_precmd()  { _yakuake_tab_title "${PWD:t}" }

    _yakuake_tab_title_preexec() {
      local cmd=${1%% *}
      [[ $cmd == (sudo|doas|env|command) ]] && cmd="$cmd ${${1#* }%% *}"
      _yakuake_tab_title "${PWD:t} - $cmd"
    }

    autoload -Uz add-zsh-hook
    add-zsh-hook precmd  _yakuake_tab_title_precmd
    add-zsh-hook preexec _yakuake_tab_title_preexec
  fi
fi
```

Reading it from the top:

- **Pre-requisites.** `$KONSOLE_DBUS_SESSION` is exported by every Konsole-family terminal, and `$+commands[gdbus]` is Zsh's associative array of executables on `PATH` evaluated arithmetically, so it is `1` when the binary is found and `0` when it is not. Together they mean the whole block is simply skipped on a machine or terminal where it does not apply.

- **Obtain session id.** When a new tab is created, the shell starting inside it *is* the active session, so asking once at startup gets us our own id and we never have to look it up again. `gdbus` prints return values as D-Bus tuples, e.g., `(5,)`, so the nested expansions strip that down to `5`: `${…#\(}` trims the leading `(` from the front and `${…%,\)}` trims the trailing `,)` from the end. `typeset -g` makes the result global so it survives into the functions defined below.

- **Value check.** `<->` is Zsh's glob operator for a sequence of digits. If the lookup failed or returned something unexpected, the hooks are never registered at all, rather than firing broken D-Bus calls on every prompt for the rest of the session.

- **Helper.** `> /dev/null 2>&1` discards both the return value and any error, so a failure never prints noise above the prompt. `&!` runs the call in the background *and* disowns it, so the process fork does not sit in the prompt's critical path and no job notification is printed. The trade-off is that two calls made in quick succession have no guaranteed ordering.

- **Idle label.** `${PWD:t}` is the "tail" modifier: the last segment of the path, so `~/Projects/MyCompany/mywebsite` becomes `mywebsite`. For two levels, i.e., `MyCompany/mywebsite`, use `${PWD:h:t}/${PWD:t}` instead.

- **Busy label.** `$1` in `preexec` is the full command line as typed, and `${1%% *}` cuts everything from the first space onwards to leave the first word. A bare first word is uninformative for wrappers, though, as every `sudo` command would read just `sudo`, so for those we append the second word as well: `${1#* }` drops the first word and `%% *` takes the first word of what is left, giving `sudo systemctl`.

- **The registration.** `add-zsh-hook` appends to the `precmd_functions` and `preexec_functions` arrays. This matters: defining `precmd()` and `preexec()` directly would silently replace whatever *Starship* or *zsh-patina* had already installed there. Because it appends rather than replaces, this block is also indifferent to the ordering rules of the previous section, as long as it comes after *Oh My Zsh* has loaded.


### Verifying and adjusting

Open a tab and ask Yakuake for the active session id by hand:

```bash
gdbus call --session --dest org.kde.yakuake \
  --object-path /yakuake/sessions \
  --method org.kde.yakuake.activeSessionId
```

A tuple such as `(0,)` means the service is reachable and the block will work. If it prints nothing, or the labels never change, there are three things worth checking:

1. **Dynamic tab titles.** Yakuake has a *Dynamic tab titles* option in its behaviour settings which makes it manage the labels itself. With it enabled, a title set over D-Bus is either ignored outright or applied and then immediately overwritten. Turn it off.

2. **Manually renamed tabs.** Renaming a tab by double-clicking it pins the label, and D-Bus calls for that tab stop taking effect afterwards.

3. **Konsole windows.** `$KONSOLE_DBUS_SESSION` is exported by Konsole as well, so if Yakuake happens to be running, a shell started in a regular Konsole window will pass the guard and relabel Yakuake's active tab from across the desktop. If you use both, compare `echo $KONSOLE_DBUS_SERVICE` in each and tighten the first condition to match only the Yakuake one.

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
