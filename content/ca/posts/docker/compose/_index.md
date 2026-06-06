---
title: "Gestió amb Compose"
description: "Gestió d'aplicacions multi-contenidor amb Docker Compose"
summary: "Gestió d'aplicacions multi-contenidor amb Docker Compose"
categories: ["teaching", "virtualisation"]
tags: ["docker", "compose"]
---

Aquests articles són els apunts de classe d'una unitat temàtica de l'assignatura Desplegament i Administració de Contenidors del segon curs del [*](CFGS) en Administració  de Sistemes Informàtics i Xarxes al [*](CIFP) [Francesc de Borja Moll](https://cifpfbmoll.eu/) de Palma.

Aquesta sèrie d'articles cobreix Docker Compose, l'eina que permet definir i executar aplicacions multi-contenidor a partir d'un fitxer YAML. Partint dels coneixements previs de Docker Engine, el contingut explora l'estructura dels fitxers Compose, la gestió de serveis, xarxes i volums, l'ús de variables d'entorn, i els fluxos de treball habituals en entorns de desenvolupament.

Cada tema combina explicacions teòriques amb exemples pràctics i exercicis, preparant l'alumnat per gestionar aplicacions complexes localment abans de fer el salt a l'orquestració amb Docker Swarm.

## Continguts de la sèrie

1. [Fonaments de Docker Compose]({{<relref "/posts/docker/compose/introduction/">}}): Aprèn els fonaments de Docker Compose, com definir serveis amb el fitxer `compose.yaml`, les comandes essencials per gestionar el cicle de vida dels contenidors i les convencions de noms automàtiques que aplica Compose.
2. [Variables d'entorn i configuració]({{<relref "/posts/docker/compose/environment/">}}): Gestió de la configuració amb variables d'entorn, fitxers .env, directiva env_file i bones pràctiques de seguretat.
3. [Xarxes i comunicació]({{<relref "/posts/docker/compose/networks/">}}): Configuració de xarxes Docker Compose, aïllament frontend/backend, resolució DNS i comunicació entre serveis.
4. [Persistència i seguretat]({{<relref "/posts/docker/compose/volumes/">}}): Gestió de volums Docker Compose, persistència de dades, bind mounts, còpies de seguretat i restauració.
5. [Construcció d'imatges]({{<relref "/posts/docker/compose/images/">}}): Construcció d'imatges personalitzades amb Docker Compose, multi-stage builds i bones pràctiques.
6. [Healthchecks i dependències]({{<relref "/posts/docker/compose/healthchecks/">}}): Configuració de healthchecks, gestió de dependències entre serveis i policymes de reinici amb Docker Compose.
7. [Perfils i entorns a Docker Compose]({{<relref "/posts/docker/compose/profiles/">}}): Gestió de perfils per activar serveis selectivament i configuració de múltiples entorns amb Docker Compose.
8. [Secrets a Docker Compose]({{<relref "/posts/docker/compose/secrets/">}}): Gestió segura de credencials amb variables d'entorn, fitxers i Docker Secrets.


<!--

| Article | Tema | Tecnologia/Exemple |
| 9 | Avançat | Odoo (Python + PostgreSQL) |
| 10 | Pràctica final | Django Ninja REST API |
-->