---
title: "Vim configuration upon OS installation and configuration"
date: 2025-07-16
lastmod: 2025-07-16
description: "Switching to Vim upon booting a new OS installation"
summary: ""
categories: ["frameworks"]
tags: ["proxmox", "editors"]
draft: true
---

For system administrators managing headless servers or working through SSH connections, VIM is often the only practical editing option. Its lightweight footprint and powerful functionality enable precise changes to critical files without the overhead of transferring files back and forth

Vim offers a unique combination of efficiency, customization, and portability that can significantly enhance a programmer's workflow. While the initial learning curve can be challenging, the long-term benefits in terms of speed, ergonomics, and versatility make it a compelling choice for many developers

It's hard to say why you would use it because we don't know your situation or preferences.

I use it because:

    I am frequently needing to edit things on random servers I've sshed into.

    I constantly have to deal with new tools and I appreciate having one that won't go obsolete in my lifetime.

    Keybindings are built into a ton of other popular tools, from shells to browsers.

    I write across a bunch of different languages and so heavy integration with one particular one isn't useful for me.

    I like the Unix philosophy of being able to interchange different parts of my pipeline, rather than having tight coupling and needing to swap all of them out at once.



    it's powerful because it's a language for talking to the editor, with verbs and objects, and the . command to mean "do that verb again on the same noun here in this new context"; I frequently issue commands that operate over whole directories of hundreds of files, consistently making precise bulk edits, saving me countless hours of time. The :*do families of commands, the :g command, and the :s command (especially with the \= replacement) are like a chainsaw for my text

    because everything can be done with my hands on the home-row (no mousing, no awkward control+alt+shift type key-combos), it's a lot easier on my wrists. When I'm stuck with another editor (or a program that requires lots of mousing or key-chords), I start developing RSI flare-up symptoms

    because it's a CLI editor, I can use it over SSH (sorta the same as #1 above, but I interpret that as "I use a lot of machines and I want effectively the same editor/environment on all of them, and vi/vim offers that" which I also appreciate)

    similarly, because it's a CLI editor, I can use it on my ancient laptops/netbooks even without firing up X for a GUI; and likewise, I can set a readable font-face/font-size in my terminal-emulator and know that vi/vim will respect those fonts

    it runs on pretty much anything (on any given day, I'm primarily on FreeBSD and OpenBSD, but also some Windows, some Linux, and occasionally some OSX; from low-end RPi with 512MB of RAM and netbooks to powerful servers with scads of RAM)

 It's less context switch for me. In combination with Tmux I have seamless workflow for navigating from one project to another one, jumping back and forth between terminals. For me it's just ease of workflow without using mouse. I am quite annoyed that I should use mouse in other IDE or to learn they proprietary motions to navigate around. And like it was said above... MY workflow works on any machine.

Optionally, switch to the full version of Vim:

```bash
apt-get purge --yes nano vim-tiny
apt-get install --yes vim
```

Set `vim` as the system-wide default editor:

```
update-alternatives --set editor /usr/bin/vim.basic
```

And set `vim` as the `root` user's default editor:

```
echo 'SELECTED_EDITOR="/usr/bin/vim.basic"' > ~/.selected_editor
```

Create the *Vim* configuration file `~/.vimrc` for the `root` user:

```
" Load defaults from /etc/vim/vimrc
runtime defaults.vim

" Disable mouse support which is enabled when loading upstream defaults
" in case /etc/vim/vimrc.local has not been deployed into the host.
set mouse=
set ttymouse=

" Disable swap and backup files for enhanced security
set noswapfile
set nobackup
set nowritebackup

" On pressing tab, insert 2 spaces
" Show existing tabs with 2 spaces width
" When indenting with '>', use 2 spaces width
set tabstop=2 softtabstop=0 expandtab shiftwidth=2 smarttab
set pastetoggle=<F3>
set nolist
set showbreak=↪\ 
set listchars=tab:→\ ,eol:↲,nbsp:␣,trail:•,extends:⟩,precedes:⟨
```
