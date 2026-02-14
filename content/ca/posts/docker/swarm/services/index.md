---
title: "Serveis a Docker Swarm"
date: 2026-01-31
lastmod: 2026-01-31
description: "Diferència entre contenidor i servei, creació de serveis, modes de desplegament i gestió de rèpliques"
summary: "Diferència contenidor/servei, creació de serveis, modes de desplegament i gestió de rèpliques"
categories: ["ensenyament"]
tags: ["docker", "swarm"]
series: ["Docker Swarm"]
series_order: 3
weight: 30
slug: serveis
---

Fins ara hem fet feina amb contenidors individuals (`docker run`) i amb grups de contenidors definits en un fitxer (`docker compose`). A Docker Swarm, el concepte central és el **servei**.

Un servei és una abstracció de més alt nivell que un contenidor. Quan cream un servei, definim l'**estat desitjat**: quina imatge utilitzar, quantes rèpliques volem, quins ports exposar, etc. Docker Swarm s'encarrega de mantenir aquest estat, creant o eliminant contenidors automàticament segons calgui.

## Contenidor vs servei

La diferència fonamental és **qui gestiona el cicle de vida**:

| Aspecte             | Contenidor (`docker run`)       | Servei (`docker service`)              |
|:--------------------|:--------------------------------|:---------------------------------------|
| Gestió              | Manual                          | Automàtica (Swarm)                     |
| Recuperació         | Si falla, queda aturat          | Si falla, es reinicia automàticament   |
| Escalat             | Cal crear contenidors un a un   | Una comanda per canviar les rèpliques  |
| Actualització       | Aturar, eliminar, crear de nou  | Rolling update sense downtime          |
| Distribució         | Una sola màquina                | Múltiples nodes del clúster            |

Amb contenidors tradicionals, usam `docker run` per crear un contenidor:

```bash
docker run -d -p 8080:80 --name web1 apache
```

I, si falla, cal reiniciar-lo manualment:

```bash
docker start web
```

A més, si volem passar a tenir tres rèpliques, cal crear-les una a una:

```bash
docker run -d -p 8081:80 --name web2 apache
docker run -d -p 8082:80 --name web3 apache
```

Amb serveis a Docker Swarm podem crear directament un servei amb tres rèpliques:

```bash
docker service create --name web --replicas 3 -p 80:80 apache
```

Si una rèplica falla, Swarm en crea una de nova automàticament. A més, per escalar necessitam una única comanda.

```bash
docker service scale web=5
```

## Crear serveis

La comanda bàsica per crear un servei és `docker service create`. Com a mínim, cal especificar un nom i una imatge:

```bash
docker service create --name web nginx
```

Això crea un servei amb una sola rèplica. Per defecte, el servei no publica cap port, així que només és accessible des de dins del clúster.

La següent taula presenta les opcions més comunes de la comanda `docker service create`:

| Opció         | Descripció                                      |
|:--------------|:------------------------------------------------|
| `--name`      | Nom del servei                                  |
| `--replicas`  | Nombre de rèpliques (per defecte: 1)            |
| `--publish`   | Publica un port (format: `PORT_HOST:PORT_CONT`) |
| `--env`       | Defineix una variable d'entorn                  |
| `--mount`     | Munta un volum o directori                      |
| `--network`   | Connecta el servei a una xarxa                  |
| `--constraint`| Restringeix on es pot executar el servei        |

Un exemple complet d'ús de la comanda seria el següent:

```bash
docker service create \
  --name api \
  --replicas 2 \
  --publish 8080:8080 \
  --env ENV=production \
  --env DB_HOST=postgres \
  --network backend \
  --mount type=volume,source=api-data,target=/data \
  myapp/api:1.0
```

Aquesta comanda crea un servei amb el nom `api` i amb dues rèpliques. El port 8080 del contenidor es publica al port 8080 de tots els nodes. A més, defineix dues variables d'entorn, `ENV` i `DB_HOST`, i connecta el servei a la xarxa `backend`, que ha d'existir prèviament. També munta el volum `api-data` al directori `/data` dins el contenidor. I ho fa usant la imatge `myapp/api` amb el tag `1.0`.

## Inspeccionar serveis

Un cop creat un servei, podem veure'l i obtenir-ne informació detallada. Començaríem amb un llistat dels serveis disponibles:

```bash
docker service ls
```

Un exemple de sortida seria el següent:

```text
ID             NAME   MODE         REPLICAS   IMAGE        PORTS
abc123def456   web    replicated   3/3        nginx:1.25   *:80->80/tcp
```

El camp `REPLICAS` mostra `3/3`, indicant que les 3 rèpliques desitjades estan en execució.

Cada rèplica d'un servei és una **tasca**. Per veure on s'executa cada tasca:

```bash
docker service ps web
```

```text
ID             NAME    IMAGE        NODE    DESIRED STATE   CURRENT STATE
abc123         web.1   nginx:1.25   node1   Running         Running 2 minutes ago
def456         web.2   nginx:1.25   node2   Running         Running 2 minutes ago
ghi789         web.3   nginx:1.25   node3   Running         Running 2 minutes ago
```

Cada tasca té un nom format pel nom del servei i un número seqüencial (`web.1`, `web.2`, `web.3`).

Per obtenir informació detallada en format JSON usam la següent comanda:

```bash
docker service inspect web
```

Si volem un resum en un format llegible afegirem el paràmetre `--pretty`:

```bash
docker service inspect --pretty web
```

## Modes de desplegament

Docker Swarm suporta dos modes de desplegament per als serveis:

| Mode         | Descripció                                          |
|:-------------|:----------------------------------------------------|
| `replicated` | Executa un nombre específic de rèpliques (per defecte) |
| `global`     | Executa exactament una tasca a cada node del clúster   |

**Mode replicated**

És el mode per defecte. Tu especifiques quantes rèpliques vols i Swarm les distribueix entre els nodes disponibles:

```bash
docker service create --name web --replicas 3 nginx
```

Si tens 3 nodes i 3 rèpliques, normalment s'executarà una rèplica a cada node. Però si tens 2 nodes i 3 rèpliques, un node tendrà 2 rèpliques.

**Mode global**

Útil per a serveis que han d'executar-se a tots els nodes, com agents de monitorització o col·lectors de logs:

```bash
docker service create --name node-exporter --mode global prom/node-exporter
```

Amb el mode global:

* Cada node existent executa una tasca.
* Quan s'afegeix un node nou, automàticament s'hi desplega una tasca.
* No es pot especificar `--replicas` (no té sentit).

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart TB
    subgraph replicated["MODE REPLICATED"]
        direction LR
        subgraph RN1["node1"]
            RT1["web.1"]
        end
        subgraph RN2["node2"]
            RT2["web.2"]
        end
        subgraph RN3["node3"]
            RT3["web.3"]
        end
        RN1 ~~~ RN2 ~~~ RN3
    end
    
    subgraph global["MODE GLOBAL"]
        direction LR
        subgraph GN1["node1"]
            GT1["agent"]
        end
        subgraph GN2["node2"]
            GT2["agent"]
        end
        subgraph GN3["node3"]
            GT3["agent"]
        end
        GN1 ~~~ GN2 ~~~ GN3
    end
    
    replicated ~~~ global
{{< /mermaid >}}

## Escalar serveis

Escalar un servei significa canviar el nombre de rèpliques. Això és trivial a Docker Swarm. Amb la mateixa comanda podem augmentar o reduir el nombre de rèpliques:

```bash
# Escalar a 5 rèpliques
docker service scale web=5

# Reduir el nombre de rèpliques
docker service scale web=2
```

Alternativament, pots usar `docker service update`:

```bash
docker service update --replicas 5 web
```

Fins i tot podem escalar múltiples serveis alhora:

```bash
docker service scale web=5 api=3
```

Quan escalam cap amunt, Swarm crea noves tasques i les distribueix entre els nodes disponibles seguint una estratègia de repartiment equilibrat (*spread*): prioritza els nodes amb manco tasques del mateix servei per aconseguir una distribució uniforme. També té en compte els recursos disponibles (CPU, RAM) i les restriccions definides (constraints).

Quan escalam cap avall, Swarm atura i elimina les tasques sobrants. La selecció de quines tasques eliminar segueix l'ordre invers de creació: les tasques més recents s'eliminen primer. A més, Swarm prioritza mantenir la distribució equilibrada entre nodes, eliminant tasques de nodes que en tenguin més d'una abans d'eliminar l'única tasca d'un node.

Podem verificar l'escalat amb la mateixa comanda que hem usat abans per a llistar els serveis:

```bash
docker service ls
```

La sortida hauria de reflexar el nou estat del servei:

```text
ID             NAME   MODE         REPLICAS   IMAGE        PORTS
abc123def456   web    replicated   5/5        nginx:1.25   *:80->80/tcp
```

## Eliminar serveis

Per eliminar un servei i totes les seves tasques usam la següent comanda:

```bash
docker service rm web
```

Això atura i elimina tots els contenidors associats al servei. L'acció és immediata i no demana confirmació.

Podem eliminar múltiples serveis de cop:

```bash
docker service rm web api database
```

## Logs de serveis

Docker Swarm permet veure els logs agregats de totes les tasques d'un servei:

```bash
docker service logs web
```

Si volem incloure el timestamp a la sortida, usarem el paràmetre `-t`:

```bash
docker service logs -t web
```

Seguint la línia habitual, podem restringir el número de línies a mostrar

```bash
docker service logs --tail 100 web
```

I també podem seguir els logs en temps real:

```bash
docker service logs -f web
```

Si volem veure els logs d'una tasca específica:

```bash
docker service logs web.1
```

## Resum

| Comanda                                   | Funció                                      |
|:------------------------------------------|:--------------------------------------------|
| `docker service create --name NOM IMATGE` | Crea un servei                              |
| `docker service ls`                       | Llista els serveis                          |
| `docker service ps SERVEI`                | Mostra les tasques d'un servei              |
| `docker service inspect SERVEI`           | Mostra informació detallada                 |
| `docker service inspect --pretty SERVEI`  | Mostra informació en format llegible        |
| `docker service scale SERVEI=N`           | Escala el servei a N rèpliques              |
| `docker service update --replicas N`      | Alternativa per escalar                     |
| `docker service logs SERVEI`              | Mostra els logs agregats del servei         |
| `docker service logs -f SERVEI`           | Segueix els logs en temps real              |
| `docker service rm SERVEI`                | Elimina el servei                           |

## Exercici pràctic

L'objectiu d'aquest exercici és familiaritzar-se amb la creació, gestió i escalat de serveis a Docker Swarm.

Requisits:

* Un clúster Docker Swarm amb almanco 3 nodes (pots reutilitzar el de l'exercici anterior).
* Connectivitat de xarxa entre els nodes.

Tasques:

1. **Crear un servei bàsic**:
   * Crea un servei anomenat `webserver` amb la imatge `nginx`.
   * Verifica que el servei està en execució amb `docker service ls`.
   * Identifica a quin node s'està executant amb `docker service ps webserver`.

2. **Publicar ports**:
   * Elimina el servei anterior.
   * Crea'l de nou publicant el port 80.
   * Des de qualsevol node (o des de fora del clúster), accedeix amb `curl http://<ip-node>:80`.
   * Comprova que funciona des de la IP de qualsevol node, no només el que executa el contenidor.

3. **Escalar el servei**:
   * Escala el servei a 3 rèpliques.
   * Verifica que hi ha una tasca a cada node.
   * Escala el servei a 5 rèpliques i observa com es distribueixen.
   * Fes que el clúster tengui una mica de tràfic:
     ```bash
     URL="http://<ip-node>:80/"
     for i in $(seq 1 10)
     do
       curl -s -o /dev/null -w "%{http_code}\n" $URL
     done
     ```
   * Redueix a 2 rèpliques i verifica quines tasques s'eliminen.

4. **Crear un servei global**:
   * Crea un servei anomenat `agent` amb mode global i la imatge `alpine` executant `sleep infinity`.
   * Verifica que hi ha una tasca a cada node.
   * Què passaria si afegissis un quart node al clúster?

5. **Logs i inspecció**:
   * Consulta els logs del servei `webserver`.
   * Inspecciona el servei amb `docker service inspect --pretty webserver`.
   * Identifica la imatge, el nombre de rèpliques i el port publicat.

6. **Neteja**:
   * Elimina tots els serveis creats.
   * Verifica que no queda cap servei amb `docker service ls`.
