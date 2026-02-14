---
title: "Introducció a Docker Swarm"
date: 2026-01-27
lastmod: 2026-01-27
description: "Què és l'orquestració de contenidors i quins són els conceptes fonamentals de Docker Swarm"
summary: "Què és l'orquestració de contenidors i els conceptes fonamentals de Docker Swarm"
categories: ["ensenyament"]
tags: ["docker", "swarm"]
series: ["Docker Swarm"]
series_order: 1
weight: 10
slug: introduccio
---

Fins ara hem après a fer feina amb contenidors individuals mitjançant [Docker Engine]({{<relref "/posts/docker/engine/">}}) i a gestionar aplicacions multi-contenidor amb [Docker Compose]({{<relref "/posts/docker/compose/">}}). Per exemple, a la pràctica anterior vam desplegar una arquitectura amb NGINX fent de balancejador de càrrega, tres rèpliques d'Apache amb PHP, PostgreSQL, Redis i MinIO, entre d'altres. Tot això en una sola màquina.

Però què passa quan necessitam:

* Executar la nostra aplicació en **múltiples servidors** per augmentar la capacitat.
* Garantir que l'aplicació **segueixi funcionant** si un servidor falla.
* **Actualitzar l'aplicació** sense interrompre el servei als usuaris.
* **Escalar automàticament** segons la demanda.

Aquí és on entra en joc l'**orquestració de contenidors**, és a dir, el procés de gestionar automàticament el desplegament, l'escalat i l'operació de contenidors a través de múltiples màquines.

L'orquestrador s'encarrega de:

* Decidir on s'executen els contenidors.
* Reiniciar contenidors que fallen.
* Distribuir la càrrega entre múltiples instàncies.
* Gestionar les actualitzacions de forma controlada.
* Mantenir la comunicació entre contenidors en diferents màquines.

## Orquestració integrada

**Docker Swarm** és la solució d'orquestració nativa de Docker. Això vol dir que:

* Està *integrada* dins del propi Docker Engine (no cal instal·lar res addicional).
* Utilitza la *mateixa sintaxi* i conceptes que ja coneixem de Docker.
* Els fitxers `docker-compose.yml` es poden adaptar fàcilment.
* La *corba d'aprenentatge* és suau per a qui ja coneix Docker.

El nom "Swarm" (eixam en anglès) fa referència a com les abelles treballen juntes de forma coordinada. De manera similar, Docker Swarm coordina múltiples màquines (nodes) perquè treballin com una sola unitat.

## Arquitectura

Un clúster de Docker Swarm està format per **nodes**, que són màquines (físiques o virtuals) amb Docker instal·lat. Hi ha dos tipus de nodes:

### Nodes gestors

Els nodes **gestors**, o **manager**, són els cervells del clúster:

* Mantenen l'**estat del clúster** (quins serveis s'executen, on, etc.).
* **Planifiquen** on s'executaran els contenidors.
* Serveixen l'**API** per gestionar el clúster.
* Prenen **decisions** quan hi ha canvis o fallades.

Per garantir alta disponibilitat, es recomana tenir un nombre **imparell** de managers (3, 5...). Això permet que el clúster segueixi funcionant encara que algun manager falli, gràcies a [l'algoritme de consens Raft](https://en.wikipedia.org/wiki/Raft_(algorithm)).

Amb 3 gestors, el clúster tolera la fallada d'1. Amb 5 gestors, en tolera 2. No es recomana tenir més de 7 gestors, ja que el rendiment del consens es degrada.

### Nodes obrers

Els nodes **obrers**, o **workers**, són els músculs del clúster:

* **Executen** els contenidors (tasques) assignats pels gestors.
* **Reporten** el seu estat als gestors.
* No participen en les decisions de gestió.

Un node pot ser alhora manager i worker (comportament per defecte dels managers), però en entorns de producció és recomanable separar els rols.

Per què separar managers i workers a producció? Els nodes manager executen l'algoritme de consens Raft, que requereix comunicació constant entre ells per mantenir l'estat del clúster. Si un manager també executa càrregues de treball intensives (contenidors d'aplicacions), el rendiment del consens es pot degradar, provocant latències en la presa de decisions o fins i tot inestabilitat del clúster. A més, separar els rols permet dimensionar els recursos de manera independent: els managers necessiten baixa latència i fiabilitat, mentre que els workers necessiten més CPU i memòria per executar les aplicacions. Finalment, en cas d'atac o compromís d'un worker, els managers romanen protegits.

### Arquitectura

El següent diagrama representa l'arquitectura de Docker Swarm.

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart TB
    subgraph managers["MANAGERS"]
        M1["Manager<br/>(líder)"]
        M2["Manager<br/>(seguidor)"]
        M3["Manager<br/>(seguidor)"]
        M1 <--->|Raft| M2
        M2 <--->|Raft| M3
        M3 <--->|Raft| M1
    end
    
    managers -->|"Assigna tasques"| workers
    
    subgraph workers["WORKERS"]
        subgraph W1["Worker 1"]
            T1["Tasca"]
            T1 --- T2["Tasca"]
        end
        subgraph W2["Worker 2"]
            T3["Tasca"]
            T3 --- T4["Tasca"]
        end
        subgraph W3["Worker 3"]
            T5["Tasca"]
        end
        W1 ~~~ W2 ~~~ W3
    end
{{< /mermaid >}}

## Conceptes clau

Cal conèixer els següents tres conceptes abans de començar a fer feina amb Docker Swarm.

### Servei

Un **servei**, o **service**, és la unitat bàsica de desplegament a Swarm. Defineix:

* Quina **imatge** de contenidor utilitzar.
* Quantes **rèpliques** (còpies) volem executar.
* Com s'han d'**actualitzar** les rèpliques.
* Quins **ports** exposar.
* A quines **xarxes** connectar-se.

La diferència fonamental amb un contenidor individual és que el servei és una **abstracció de més alt nivell**: definim l'estat desitjat (e.g., "vull 3 rèpliques del meu servidor web") i Swarm s'encarrega de mantenir-lo.

```bash
# Amb Docker tradicional
docker run -d -p 80:80 nginx

# Amb Docker Swarm
docker service create --replicas 3 -p 80:80 nginx
```

Recordes les 3 rèpliques d'Apache que vam configurar manualment a Docker Compose? Amb Swarm, si una rèplica falla, el sistema en crea una de nova automàticament.

### Tasca

Una **tasca**, o **task**, és la unitat mínima de planificació a Swarm. Cada tasca representa:

* Un **contenidor** en execució.
* Assignat a un **node** específic.
* Amb un **estat** (`running`, `shutdown`, `failed`, etc.).

Quan cream un servei amb 3 rèpliques, Swarm crea 3 tasques, cadascuna executant un contenidor en algun node del clúster.

### Pila

Una **pila**, o **stack**, és un conjunt de serveis relacionats que es despleguen junts, definits en un fitxer YAML (similar a `docker-compose.yml`). Permet gestionar aplicacions complexes com una unitat.

```yaml
# stack.yml
version: "3.8"
services:
  web:
    image: nginx
    deploy:
      replicas: 3
  api:
    image: myapi:latest
    deploy:
      replicas: 2
  db:
    image: postgres:18
```

## Flux de feina

El funcionament de Docker Swarm segueix un patró de **reconciliació contínua**:

1. **Definició**: L'administrador defineix un servei (imatge, rèpliques, xarxes...).
2. **Planificació**: El manager decideix en quins nodes s'executaran les tasques.
3. **Execució**: Els workers creen i executen els contenidors.
4. **Monitorització**: Els managers supervisen constantment l'estat.
5. **Reconciliació**: Si una tasca falla, el manager en crea una de nova automàticament.

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart TB
    A["Administrador"]
    A -->|"Defineix servei"| M["Manager"]
    M -->|"Planifica"| W["Workers"]
    
    subgraph reconciliacio["Reconciliació contínua"]
        ED["Estat desitjat"]
        EA["Estat actual"]
        ED <--> EA
    end
    
    M --- reconciliacio
    reconciliacio --- W
{{< /mermaid >}}

## Quan utilitzar-lo

Docker Swarm és especialment adequat quan:

* Ja utilitzes Docker i vols una transició suau a l'orquestració.
* Tens una aplicació de **complexitat mitjana**.
* Necessites **alta disponibilitat** sense massa configuració.
* L'equip té experiència amb Docker però no amb Kubernetes.
* Vols una solució **senzilla de mantenir**.

Per a entorns amb requisits molt avançats (autoescalat basat en mètriques, gestió de múltiples clústers, ecosistema molt extens de plugins), Kubernetes pot ser més adequat.

| Característica                | Docker Swarm                      | Kubernetes                        |
| :---------------------------- | :-------------------------------- | :-------------------------------- |
| Complexitat d'instal·lació    | Baixa (integrat a Docker)         | Alta (múltiples components)       |
| Corba d'aprenentatge          | Suau                              | Pronunciada                       |
| Escalabilitat                 | Milers de nodes                   | Desenes de milers de nodes        |
| Autoescalat                   | Manual o amb eines externes       | Integrat (HPA, VPA)               |
| Balanceig de càrrega          | Integrat (routing mesh)           | Requereix Ingress Controller      |
| Gestió de secrets             | Integrada                         | Integrada                         |
| Monitorització                | Bàsica (requereix eines externes) | Extensa amb ecosistema ric        |
| Comunitat i ecosistema        | Menor                             | Molt gran                         |
| Cas d'ús ideal                | Aplicacions petites/mitjanes      | Aplicacions grans i complexes     |
| Integració amb Docker Compose | Nativa                            | Requereix conversió (Kompose)     |
