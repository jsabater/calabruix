---
title: "2nd Level Adaptive Replacement Cache"
date: 2024-09-16
---

El 2nd Level Adaptive Replacement Cache (L2ARC) de ZFS és una memòria cau basada en SSD a la qual s'accedeix abans de llegir dels discs del pool, molt més lents.

Quan un sistema rep sol·licituds de lectura, ZFS utilitza l'ARC (RAM) per servir aquestes sol·licituds. Quan l'ARC està ple i hi ha unitats L2ARC assignades a un pool ZFS, ZFS utilitza el L2ARC per servir les sol·licituds de lectura que han desbordat de l'ARC. Això redueix l'ús de discs durs més lents i, per tant, augmenta el rendiment del sistema.

El L2ARC està actualment pensat per a càrregues de treball de lectura aleatòria.
