---
title: "Docker Engine"
date: 2026-03-23
lastmod: 2026-03-23
description: "Fonaments de Docker: instal·lació, contenidors, imatges, volums i xarxes"
summary: "Fonaments de Docker: instal·lació, contenidors, imatges, volums i xarxes"
categories: ["teaching", "virtualisation"]
tags: ["docker", "engine"]
---

Aquests articles són els apunts de classe d'una unitat temàtica de l'assignatura Desplegament i Administració de Contenidors del segon curs del [*](CFGS) en Administració  de Sistemes Informàtics i Xarxes al [*](CIFP) [Francesc de Borja Moll](https://cifpfbmoll.eu/) de Palma.

Aquesta sèrie d'articles introdueix els fonaments de la contenització amb Docker. El contingut avança des de la instal·lació i els primers passos amb contenidors fins a conceptes més avançats com la gestió d'imatges, la creació d'imatges personalitzades amb Dockerfile, la persistència de dades amb volums, i la configuració de xarxes.

Cada tema combina explicacions teòriques amb exemples pràctics i exercicis per consolidar els coneixements, establint la base necessària per a les sèries posteriors sobre [Docker Compose]({{<relref "/posts/docker/compose/">}}) i [Docker Swarm]({{<relref "/posts/docker/swarm/">}}).

## Continguts de la sèrie

1. [Introducció a Docker]({{<relref "/posts/docker/engine/introduction/" >}}): Context històric, arquitectura, comparativa amb VMs i altres tecnologies.
2. [Instal·lació i primers passos]({{<relref "/posts/docker/engine/installation/" >}}): Instal·lació a Debian/Ubuntu, primers comandaments, descàrrega d'imatges.
3. [Gestió de contenidors]({{<relref "/posts/docker/engine/management/" >}}): Execució, inspecció, logs, interacció i còpia de fitxers.
4. [Volums i persistència]({{<relref "/posts/docker/engine/volumes/" >}}): Tipus de muntatge, gestió de volums, bind mounts.
5. [Dockerfiles i construcció d'imatges]({{<relref "/posts/docker/engine/dockerfiles/" >}}): Instruccions, `.dockerignore`, capes, cache i multi-stage builds.
6. [Xarxes Docker]({{<relref "/posts/docker/engine/networks/" >}}): Tipus de xarxes, resolució DNS, comunicació entre contenidors.
7. [Projectes multi-contenidor]({{<relref "/posts/docker/engine/" >}}): Organització, gestió de recursos i preparació per a Docker Compose.