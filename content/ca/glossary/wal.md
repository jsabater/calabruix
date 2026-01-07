---
title: "Write-Ahead Log"
date: 2025-03-24
---

Un Write-Ahead Log (WAL) és un mètode estàndard per assegurar la integritat de les dades. El seu concepte central és que els canvis als fitxers de dades només s'han d'escriure després que aquests canvis hagin estat registrats, és a dir, després que els registres WAL que descriuen els canvis hagin estat escrits a l'emmagatzematge permanent.

