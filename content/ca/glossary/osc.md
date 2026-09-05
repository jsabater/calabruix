---
title: "Operating System Command"
date: 2026-09-05
---

Operating System Command (OSC) és una de les funcions de control definides a l'ECMA-48 (l'estàndard que hi ha al darrere de les seqüències d'escapament ANSI), juntament amb CSI (Control Sequence Introducer), el prefix `\e[` que veiem als codis de color.

Una seqüència OSC és `\e]` seguida d'una ordre numèrica, un punt i coma, la càrrega útil i un terminador, que pot ser BEL (`\a`) o bé ST, l'String Terminator (`\e\`).

El nom reflecteix per a què servia originalment: a diferència de les seqüències CSI, que manipulen la pantalla mateixa (moviment del cursor, colors, esborrat), les seqüències OSC passen dades a l'entorn amfitrió que envolta el terminal, és a dir, el gestor de finestres, la barra de títol i, més endavant, coses com l'accés al porta-retalls (OSC 52) i els enllaços (OSC 8).
