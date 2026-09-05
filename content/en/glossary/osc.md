---
title: "Operating System Command"
date: 2026-09-05
---

Operating System Command (OSC) is one of the control functions defined in ECMA-48 (the standard behind ANSI escape sequences), alongside CSI (Control Sequence Introducer), the `\e[` prefix we see in colour codes.

An OSC sequence is `\e]` followed by a numeric command, a semicolon, the payload, and a terminator, which can be either BEL (`\a`) or ST, the String Terminator (`\e\`).

The name reflects what it was for originally: unlike CSI sequences, which manipulate the screen itself (cursor movement, colours, erasing), OSC sequences pass data to the host environment around the terminal, i.e., the window manager, the title bar, and later on things like clipboard access (OSC 52) and hyperlinks (OSC 8).
