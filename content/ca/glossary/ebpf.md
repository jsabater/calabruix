---
title: "Extended Berkeley Packet Filter"
date: 2026-11-09
---

Extended Berkeley Packet Filter (eBPF) és una tecnologia del nucli de Linux que permet executar programes en un entorn controlat dins del propi nucli sense modificar-ne el codi font ni carregar mòduls. Els programes, escrits en un subconjunt de C, es compilen a bytecode eBPF mitjançant LLVM, es verifiquen estàticament per un verificador integrat i es compilen *just-in-time* a codi natiu per executar-se amb rendiment proper al d'un mòdul del nucli.

S'adossen a punts d'enganxament (*hooks*) del nucli, e.g., cridades de sistema, *tracepoints*, *kprobes*, *XDP* o *cgroup*, i s'han convertit en la base actual d'eines d'observabilitat, seguretat i *networking*. 
