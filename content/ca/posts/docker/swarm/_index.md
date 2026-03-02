---
title: "Orquestració amb Swarm"
description: "Orquestració de contenidors en clústers amb Docker Swarm"
summary: "Orquestració de contenidors en clústers amb Docker Swarm"
categories: ["teaching", "virtualisation"]
tags: ["docker", "swarm"]
---

Aquests articles són els apunts de classe d'una unitat temàtica de l'assignatura Desplegament i Administració de Contenidors del segon curs del [*](CFGS) en Administració  de Sistemes Informàtics i Xarxes al [*](CIFP) [Francesc de Borja Moll](https://cifpfbmoll.eu/) de Palma.

Aquesta sèrie d'articles introdueix l'orquestració de contenidors amb Docker Swarm, la solució nativa de Docker per gestionar aplicacions distribuïdes en múltiples màquines.

Partint dels coneixements previs de [Docker]({{<relref "/posts/docker/engine/">}}) i [Docker Compose]({{<relref "/posts/docker/compose/">}}), el contingut avança progressivament des dels conceptes fonamentals d'arquitectura (nodes manager i worker, serveis, tasques) fins a aspectes avançats com les actualitzacions sense downtime, la gestió de xarxes overlay, la persistència de dades en entorns distribuïts, i la configuració segura amb secrets.

Cada tema combina explicacions teòriques amb exemples pràctics i exercicis per consolidar els coneixements, preparant l'alumnat per desplegar i mantenir aplicacions en clústers Docker Swarm.

## Continguts de la sèrie

1. [Introducció a Docker Swarm]({{< relref "/posts/docker/swarm/introduction/" >}}): Què és l'orquestració de contenidors i quins són els conceptes fonamentals de Docker Swarm.
2. [Creació i gestió d'un clúster Docker Swarm]({{< relref "/posts/docker/swarm/creation/" >}}): Com inicialitzar un clúster Docker Swarm, afegir nodes i gestionar-los.
3. [Serveis a Docker Swarm]({{< relref "/posts/docker/swarm/services/" >}}): Diferència entre contenidor i servei, creació de serveis, modes de desplegament i gestió de rèpliques.
4. [Actualització i manteniment de serveis]({{< relref "/posts/docker/swarm/update/" >}}): Rolling updates, rollback, gestió de fallades i actualitzacions sense downtime.
5. [Xarxes a Docker Swarm]({{< relref "/posts/docker/swarm/network/" >}}): Xarxes overlay, descobriment de serveis, balanceig de càrrega i routing mesh.
6. [Persistència de dades a Swarm]({{< relref "/posts/docker/swarm/persistance/" >}}): Reptes de la persistència en entorns distribuïts, volums locals i estratègies per a serveis amb estat.
7. [De Docker Compose a Docker Swarm amb Stacks]({{< relref "/posts/docker/swarm/stacks/" >}}): Desplegament d'aplicacions multi-servei amb Docker Stack i fitxers Compose.
8. [Configuració i secrets]({{< relref "/posts/docker/swarm/configs-secrets/" >}}): Gestió segura de configuració i credencials amb Docker Configs i Docker Secrets.
9. [Desplegament d'una aplicació Django amb Swarm]({{< relref "/posts/docker/swarm/example/" >}}): Cas pràctic complet: desplegament d'una aplicació Django amb Traefik, PostgreSQL, Redis i Celery.
10. [Automatització del desplegament]({{< relref "/posts/docker/swarm/automation/" >}}): Scripts de desplegament, gestió automatitzada de configs i secrets, i pipelines de desplegament.
11. [Estratègies de desplegament avançades]({{< relref "/posts/docker/swarm/deployment-strategies/" >}}): Rolling updates, desplegaments Blue-Green, rollback i gestió de fallades.
12. [Alta disponibilitat i producció]({{< relref "/posts/docker/swarm/high-availability" >}}): Múltiples managers, xifratge de xarxes, backups i consideracions per a entorns de producció.
<!--
13. [Monitorització i troubleshooting]({{< relref "/posts/docker/swarm/" >}}):
14. [Pràctica final]({{< relref "/posts/docker/swarm/" >}}):
-->