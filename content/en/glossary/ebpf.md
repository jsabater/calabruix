---
title: "Extended Berkeley Packet Filter"
date: 2026-11-09
---

Extended Berkeley Packet Filter (eBPF) is a Linux kernel technology that allows programs to run in a sandboxed environment inside the kernel without modifying kernel source code or loading kernel modules. Programs, written in a subset of C, are compiled to eBPF bytecode via LLVM, statically verified by an in-kernel verifier, and then compiled just-in-time to native code for near-native execution speed.

They attach to kernel hook points, e.g., system calls, tracepoints, kprobes, XDP, or cgroup hooks, and have become the current foundation for observability, security, and networking tools.
