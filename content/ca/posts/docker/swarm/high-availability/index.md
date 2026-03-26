---
title: "Alta disponibilitat i producció"
date: 2026-03-02
lastmod: 2026-03-02
description: "Múltiples managers, xifratge de xarxes, backups i consideracions per a entorns de producció"
summary: "Múltiples managers, xifratge de xarxes, backups i consideracions per a entorns de producció"
categories: ["teaching"]
tags: ["docker", "swarm", "production", "high-availability", "backup"]
series: ["Docker Swarm"]
series_order: 12
weight: 120
slug: alta-disponibilitat
---

Fins ara hem fet feina amb clústers de proves on la disponibilitat no era crítica. En aquest article veurem com configurar un clúster Docker Swarm per a entorns de producció, garantint alta disponibilitat, seguretat i capacitat de recuperació davant fallades.

## Múltiples managers

En un clúster de producció, tenir un sol manager és un punt únic de fallada. Si el manager cau, no es poden fer canvis al clúster fins que es recuperi. Per evitar-ho, Docker Swarm permet tenir múltiples managers que mantenen l'estat del clúster de forma distribuïda usant l'[algorisme de consens Raft](https://en.wikipedia.org/wiki/Raft_(algorithm)).

### Quòrum

El quòrum és el nombre mínim de managers que han d'estar disponibles perquè el clúster pugui funcionar. Swarm requereix que més de la meitat dels managers estiguin actius:

Es calcula com `(n/2) + 1`, on `n` és el nombre total de managers:

| Managers totals | Quòrum mínim | Tolerància a fallades |
|:---------------:|:------------:|:---------------------:|
| 1               | 1            | 0                     |
| 2               | 2            | 0                     |
| 3               | 2            | 1                     |
| 5               | 3            | 2                     |
| 7               | 4            | 3                     |

Observacions:

* Amb 2 managers no hi ha cap avantatge respecte a 1, perquè si un cau, es perd el quòrum.
* El nombre de managers ha de ser senar per maximitzar la tolerància a fallades.
* La recomanació per a producció és 3 ò 5 managers.
* Més de 7 managers no és recomanable perquè el temps de consens augmenta.

### Afegir managers

Per convertir un clúster d'un sol manager en un clúster amb múltiples managers, primer obtenim el token de manager:

```bash
docker swarm join-token manager
```

Això mostra una comanda que executarem als nodes que volem afegir com a managers:

```bash
docker swarm join --token SWMTKN-1-xxx <ip_manager>:2377
```

Per verificar l'estat dels managers usarem la següent comanda:

```bash
docker node ls
```

La sortida mostra tots els nodes amb el seu rol i estat:

```
ID         HOSTNAME   STATUS   AVAILABILITY   MANAGER STATUS
abc123 *   node1      Ready    Active         Leader
def456     node2      Ready    Active         Reachable
ghi789     node3      Ready    Active         Reachable
jkl012     node4      Ready    Active         
```

El camp `Manager status` determina el rol del node gestor al clúster:

* `Leader`: El manager que coordina les operacions d'escriptura.
* `Reachable`: Managers seguidors, disponibles per assumir el lideratge si cal.
* `<buit>`: Workers, no participen en el consens.

### Promoció i degradació

Podem canviar el rol d'un node en qualsevol moment. Per promoure un worker a manager usarem la següent ordre:

```bash
docker node promote node4
```

I per a degradar un node manager a worker usarem la següent:

```bash
docker node demote node3
```

{{< alert >}}
Si degradam massa managers i perdem el quòrum, el clúster queda inoperatiu.
{{< /alert >}}

### Disponibilitat

Els managers, per defecte, també executen tasques com a workers. Però podem canviar aquest comportament. Per exemple, per evitar que un gestor executi tasques usarem la següent comanda:

```bash
docker node update --availability drain node1
```

I per a permetre que un node gestor torni a executar tasques usarem aquesta:

```bash
docker node update --availability active node1
```

Els valors possibles són:

| Valor    | Descripció                                                          |
|:---------|:--------------------------------------------------------------------|
| `active` | El node accepta tasques noves                                       |
| `pause`  | El node no accepta tasques noves, però manté les existents          |
| `drain`  | El node no accepta tasques noves i mou les existents a altres nodes |

En clústers petits (3 nodes), és habitual que els managers també siguin workers. En clústers més grans, es recomana dedicar els managers exclusivament a tasques de gestió usant `drain`.

### Recuperació

Si perdem el quòrum (per exemple, 2 de 3 managers cauen), el clúster no pot fer canvis. Per recuperar-lo, hem de reinicialitzar el quòrum des d'un manager que hagi sobreviscut la catàstrofe:

```bash
docker swarm init --force-new-cluster --advertise-addr <ip_manager>
```

Aquesta comanda:

* Crea un nou clúster amb un sol manager.
* Preserva els serveis, xarxes, secrets i configs existents.

Una vegada inicialitzat, els altres managers i workers s'han de tornar a unir al clúster. Quan haguem tornat a afegir managers tornarem a gaudir d'alta disponibilitat.

## Xifratge de xarxes

Docker Swarm xifra automàticament el tràfic del pla de control (gestió del clúster, Raft log, comunicació entre managers). Però el tràfic de dades entre contenidors a les xarxes overlay **no està xifrat per defecte**.

Per xifrar el tràfic de dades, afegim l'opció `encrypted` a la xarxa overlay:

```yaml
networks:
  backend:
    driver: overlay
    driver_opts:
      encrypted: "true"
    internal: true
```

Això activa el xifratge IPsec per a tot el tràfic que passa per aquesta xarxa.

La necessitat de xifratge depèn de l'entorn:

| Escenari                                                | Xifrar? |
|:--------------------------------------------------------|:--------|
| Nodes al mateix rack o xarxa privada física             | No      |
| VPS amb xarxa privada virtual (Hetzner, OVH, Hostinger) | Sí      |
| Nodes a diferents centres de dades                      | Sí      |
| Dades sensibles subjectes a normativa específica[^1]    | Sí      |
| Clúster de proves o desenvolupament                     | No      |

[^1]: Exemples serien salut o finances.

Els proveïdors de VPS com Hetzner, OVH o Hostinger ofereixen xarxes privades virtuals (vSwitch, vRack, etc.), però el tràfic no està xifrat. Tot i que no és accessible des d'Internet, teòricament altres clients al mateix segment físic podrien interceptar-lo.

**Impacte en el rendiment**

El xifratge IPsec té un cost computacional. En la majoria de casos, l'impacte és mínim (5-10%), però pot ser significatiu en aplicacions amb molt tràfic intern. És recomanable fer proves de rendiment abans i després d'activar el xifratge.

Per a xarxes amb molt tràfic que no requereixen xifratge (per exemple, entre l'aplicació i una base de dades a la mateixa màquina física), podem mantenir xarxes separades:

```yaml
networks:
  backend:
    driver: overlay
    driver_opts:
      encrypted: "true"
    internal: true
  
  database:
    driver: overlay
    internal: true
    # Sense xifratge, només per a tràfic local
```

## Etiquetatge de nodes

Les etiquetes permeten organitzar els nodes i controlar on s'executen els serveis. Són clau per a una arquitectura de producció ben estructurada.

A l'hora d'afegir etiquetes, podem fer-ho per funció, per ubicació o per capacitat, entre d'altres. Exemples d'etiquetatge per funció podrien ser els següents:

```bash
docker node update --label-add role=database node1
docker node update --label-add role=application node2
docker node update --label-add role=application node3
```

Exemples d'etiquetatge de nodes per ubicació podrien ser els següents:

```bash
docker node update --label-add zone=eu-hetzner-fsn node1
docker node update --label-add zone=eu-ovh-rbx node2
docker node update --label-add zone=eu-arsys-prt node3
```

Finalment, exemples d'etiquetatge de nodes per capacitat podrien ser els següents:

```bash
docker node update --label-add storage=ssd node1
docker node update --label-add storage=hdd node2
```

Per veure les etiquetes d'un node usarem la següent comanda:

```bash
docker node inspect --pretty node1
```

I per veure les etiquetes de tots els nodes usarem la següent ordre:

```bash
docker node ls -q | xargs -I {} docker node inspect \
--format '{{.Description.Hostname}}: {{.Spec.Labels}}' {}
```

### Constraints

També podem usar les etiquetes per controlar on s'executen els serveis:

```yaml
services:
  postgres:
    image: postgres:18-alpine
    deploy:
      placement:
        constraints:
          - node.labels.role == database
          - node.labels.storage == ssd

  web:
    image: myuser/myapp:latest
    deploy:
      placement:
        constraints:
          - node.labels.role == application
```

### Preferències

A diferència de les restriccions, que són obligatòries, les preferències intenten distribuir les tasques segons un criteri, però no fallen si no es pot complir:

```yaml
services:
  web:
    image: myuser/myapp:latest
    deploy:
      replicas: 6
      placement:
        constraints:
          - node.labels.role == application
        preferences:
          - spread: node.labels.zone
```

Aquesta configuració intenta distribuir les 6 rèpliques equitativament entre les zones disponibles.

## Còpies de seguretat

Un pla de còpies de seguretat és essencial per a qualsevol entorn de producció. En un clúster Docker Swarm hem de fer còpia de seguretat de dos tipus de dades: l'estat del clúster i les dades dels volums.

### Estat del clúster

L'estat del clúster (serveis, xarxes, secrets i configuracions) es guarda al directori `/var/lib/docker/swarm` dels managers. La còpia de seguretat del clúster guarda informació que no és trivial de recrear:

* Secrets: Els valors dels secrets no es poden recuperar un cop creats. Sense backup, caldria regenerar-los tots i actualitzar les aplicacions i serveis externs que en depenen.
* Configs: Fitxers de configuració versionats que caldria recrear manualment.
* Històric de Raft: L'estat de consens del clúster, incloent l'historial de canvis als serveis.
* Certificats interns: Els certificats TLS que Swarm genera automàticament per a la comunicació entre nodes.
* Tokens d'unió: Els tokens per afegir nous managers i workers.

Per a un clúster petit amb pocs secrets i una configuració simple, potser és una opció inicialitzar el clúster de nou i recrear-ho tot. Però en entorns de producció amb desenes de secrets, configuracions complexes i múltiples serveis, tenir una còpia de seguretat pot estalviar hores de feina i reduir el risc d'errors durant la recuperació.

Per fer-ne còpia de seguretat:

1. Aturar Docker temporalment (opcional però recomanat):
```bash
   sudo systemctl stop docker
```

2. Copiar el directori:
```bash
   tar -czvf swarm-backup-$(date +%Y%m%d).tar.gz /var/lib/docker/swarm
```

3. Arrancar Docker de nou:
```bash
   sudo systemctl start docker
```

Consideracions:

* Fer la còpia des d'un manager, preferiblement el líder.
* Quan aturem Docker a un manager, un altre manager assumeix el lideratge automàticament. Els serveis continuen funcionant als altres nodes. En un clúster amb 3+ managers, aquesta operació és segura.
* Si no aturem Docker, podem fer la còpia en calent, però hi ha risc d'inconsistència.
* Guardar les còpies fora del clúster.

### Dades dels volums

Els volums contenen les dades persistents de les aplicacions: bases de dades, fitxers pujats, etc. La forma recomanada de gestionar aquestes còpies és amb [Borgmatic](https://torsion.org/borgmatic/), una eina que integra Borg Backup amb suport per a bases de dades.

Borgmatic permet:

* Fer còpies de fitxers i directoris.
* Executar `pg_dump` abans de la còpia (hooks).
* Executar `redis-cli BGSAVE` abans de la còpia (hooks).
* Xifrar, comprimir i deduplicar automàticament.
* Verificar i netejar còpies antigues.

Exemple de configuració de Borgmatic per al nostre stack, tenint en compte que Borgmatic s'executi com a servei de l'stack amb accés a la xarxa overlay del clúster, el que permet fer *streaming* directe sense passar per `docker exec`:

```yaml
# docker/borgmatic/config.yaml
#
# Configuració per a Borgmatic executant-se dins un contenidor
# amb accés a la xarxa overlay de Swarm.

source_directories:
  - /data/uploads
  - /tmp/redis-dump.rdb

repositories:
  - path: /var/backups/borg
    label: local

postgresql_databases:
  - name: myapp
    username: myapp
    password: ${POSTGRES_PASSWORD}
    hostname: postgres  # Nom del servei a la xarxa overlay
    port: 5432

before_backup:
  # Streaming directe via xarxa overlay
  # Requereix redis-cli al contenidor de backups
  - redis-cli -h redis -p 6379 --rdb - > /tmp/redis-dump.rdb
  
after_backup:
  - rm -f /tmp/redis-dump.rdb

retention:
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 6

encryption_passphrase: ${BORG_PASSPHRASE}
```

A continuació es mostren les comandes manuals equivalents, útils per entendre el procés o per a situacions puntuals.

**PostgreSQL**
```bash
POSTGRES_CONTAINER=$(docker ps -q -f name=myapp_postgres)
docker exec ${POSTGRES_CONTAINER} \
pg_dump --username=myapp myapp > postgres-$(date +%Y%m%d).sql
```

**Redis**
```bash
# Opció amb streaming
REDIS_CONTAINER=$(docker ps -q -f name=myapp_redis)
docker exec --interactive ${REDIS_CONTAINER} \
redis-cli --rdb - > redis-$(date +%Y%m%d).rdb
```

**Fitxers**
```bash
tar --create --gzip --file=uploads-$(date +%Y%m%d).tar.gz \
/var/lib/docker/volumes/myapp_uploads
```

> Per a una gestió més avançada de bases de dades (restauracions parcials, múltiples backends, retenció granular), es pot tenir en compte [Databasus](https://github.com/databasus/databasus).

### Servei Borgmatic

Si volguéssim tenir [Borgmatic com a servei](https://github.com/borgmatic-collective/docker-borgmatic) a l'stack, podríem modificar el nostre fitxer `docker-stack.yml` amb el següent exemple:

```yaml
# docker-stack.yml

services:
  # ...

  borgmatic:
    image: ghcr.io/borgmatic-collective/borgmatic
    volumes:
      # Volums a fer backup
      - myapp_uploads:/data/uploads:ro
      # Repositori de Borg (pot ser un volum o muntatge NFS)
      - borgmatic_repo:/var/backups/borg
      # Temporal per a Redis (recomanat tmpfs)
      - type: tmpfs
        target: /tmp
    configs:
      - source: borgmatic_config
        target: /etc/borgmatic/config.yaml
    environment:
      - CRON_SCHEDULE=0 3 * * *  # Cada dia a les 3:00
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
      - BORG_PASSPHRASE_FILE=/run/secrets/borg_passphrase
    secrets:
      - postgres_password
      - borg_passphrase
    networks:
      - backend
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager

volumes:
  # ...
  borgmatic_repo:
    driver: local

configs:
  borgmatic_config:
    file: docker/borgmatic/config.yaml

secrets:
  # ...
  borg_passphrase:
    external: true
```

Deixar el servei amb replicas: 1 permanentment és la manera més senzilla. El contenidor consumeix recursos mínims quan no està fent backup, i tenim l'avantatge de:

* Programació integrada amb la variable `CRON_SCHEDULE`.
* Logs centralitzats amb docker service logs.
* Reinici automàtic si el contenidor falla.

Cal inicialitzar el repositori de Borg abans del primer backup:

```bash
BORGMATIC_CONTAINER=$(docker ps -q -f name=myapp_borgmatic)
docker exec -it ${BORGMATIC_CONTAINER} \
borgmatic init --encryption repokey
```

### Bones pràctiques

1. Regla 3-2-1: 3 còpies, 2 mitjans diferents, 1 fora del lloc.
2. Verificar les còpies, restaurant-les periòdicament per confirmar que funcionen, idealment cada dia i de forma automatitzada.
3. Xifrar les còpies, especialment si es guarden fora del clúster, i guardar la clau de xifratge en una bòveda.
4. Documentar el procés, tant de backup com de restauració.
5. Monitoritzar l'execució, configurant alertes que enviïn missatges en cas que un backup falli.

## Xarxa

Un seguit de consideracions importants per a un entorn de producció hostejat a proveïdors de servidors dedicats o màquines virtuals.

### Xarxes privades

En proveïdors de VPS, és recomanable usar xarxes privades per al tràfic intern del clúster:

* Hetzner: vSwitch o Cloud Networks.
* OVH: vRack.
* Hostinger: VPS amb IP privada.

Els paràmetres `--advertise-addr` i `--listen-addr` haurien d'apuntar a la IP privada. Per exemple:

```bash
docker swarm init --advertise-addr 10.0.0.1 --listen-addr 10.0.0.1:2377
```

### Ports

Els nodes del clúster necessiten comunicar-se entre ells a través de diversos ports:

| Port | Protocol | Funció                            |
|:-----|:---------|:----------------------------------|
| 2377 | TCP      | Gestió del clúster (API de Swarm) |
| 7946 | TCP/UDP  | Comunicació entre nodes (gossip)  |
| 4789 | UDP      | Tràfic de xarxes overlay (VXLAN)  |

A més, si usem xifratge de xarxes overlay, cal permetre el protocol ESP (IP protocol 50).

### Tallafocs

Al marge dels serveis que ens ofereixi el proveïdor de VPS, és necessari configurar un tallafocs a cada servidor o VPS. Exemple amb `ufw`:

```bash
# Ports de Swarm (només des d'IPs del clúster)
ufw allow from 10.0.0.0/24 to any port 2377 proto tcp
ufw allow from 10.0.0.0/24 to any port 7946 proto tcp
ufw allow from 10.0.0.0/24 to any port 7946 proto udp
ufw allow from 10.0.0.0/24 to any port 4789 proto udp

# Protocol ESP per al xifratge
ufw allow from 10.0.0.0/24 proto esp

# Ports públics (Traefik)
ufw allow 80/tcp
ufw allow 443/tcp
```

## Verificació

Abans de posar un clúster en producció, cal verificar els següents punts:

Infraestructura:

* [ ] Mínim 3 managers en nodes separats.
* [ ] Nodes distribuïts en diferents racks o zones (si és possible).
* [ ] Xarxa privada configurada entre nodes.
* [ ] Firewall configurat amb els ports necessaris.
* [ ] Accés SSH amb claus (sense contrasenyes).

Seguretat:

* [ ] Xifratge activat a les xarxes overlay amb dades sensibles.
* [ ] Secrets de Docker per a credencials (no variables d'entorn).
* [ ] Certificats TLS per al tràfic extern.
* [ ] Usuari no-root als contenidors (quan sigui possible).
* [ ] Imatges actualitzades i escanejades per vulnerabilitats.

Alta disponibilitat:

* [ ] Serveis crítics amb múltiples rèpliques.
* [ ] Healthchecks configurats als serveis.
* [ ] Constraints per distribuir rèpliques entre nodes.
* [ ] `update_config` amb `failure_action: rollback`.

Backups:

* [ ] Backup diari de bases de dades.
* [ ] Backup de l'estat del clúster.
* [ ] Backups verificats (proves de restauració).
* [ ] Backups guardats fora del clúster.

Monitorització:

* [ ] Logs centralitzats.
* [ ] Mètriques de recursos (CPU, memòria, disc).
* [ ] Alertes per a serveis caiguts o recursos exhaurits.
* [ ] Dashboards per a visualització.

Documentació:

* [ ] Arquitectura del clúster documentada.
* [ ] Procediments de desplegament.
* [ ] Procediments de recuperació.
* [ ] Contactes per a incidències.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l’aprenentatge progressiu.

### Exercici 1

**Clúster amb múltiples managers**

Crea un clúster amb 3 managers i practica la recuperació de fallades.

Tasques:

1. Inicialitza un clúster amb el primer manager:
   ```bash
   docker swarm init --advertise-addr <ip_node1>
   ```

2. Obtén el token de manager i afegeix dos managers més:
   ```bash
   docker swarm join-token manager
   # Executa la comanda als altres nodes
   ```

3. Verifica l'estat del clúster:
   ```bash
   docker node ls
   ```

4. Simula la caiguda d'un manager (atura Docker a un dels managers):
   ```bash
   systemctl stop docker
   ```

5. Verifica que el clúster encara funciona:
   ```bash
   docker node ls
   docker service ls
   ```

6. Recupera el manager caigut:
   ```bash
   systemctl start docker
   ```

7. Practica la promoció i degradació de nodes.

### Exercici 2

**Xifratge i etiquetatge**

Configura xarxes xifrades i organitza els nodes amb etiquetes.

Tasques:

1. Afegeix etiquetes als nodes del clúster:
   ```bash
   docker node update --label-add role=database node1
   docker node update --label-add role=application node2
   docker node update --label-add role=application node3
   ```

2. Modifica el fitxer `docker-stack.yml` per usar xarxes xifrades:
   ```yaml
   networks:
     backend:
       driver: overlay
       driver_opts:
         encrypted: "true"
       internal: true
   ```

3. Afegeix constraints als serveis:
   ```yaml
   services:
     postgres:
       deploy:
         placement:
           constraints:
             - node.labels.role == database
     web:
       deploy:
         placement:
           constraints:
             - node.labels.role == application
   ```

4. Desplega l'stack i verifica que els serveis s'executen als nodes correctes:
   ```bash
   docker stack deploy -c docker-stack.yml myapp
   docker service ps myapp_postgres
   docker service ps myapp_web
   ```

### Exercici 3

**Còpies de seguretat**

Implementa un sistema de còpies de seguretat per al clúster usant Borgmatic.

Tasques:

1. Crea el fitxer de configuració de Borgmatic a `docker/borgmatic/config.yaml` seguint l'exemple de l'article.

2. Afegeix el servei Borgmatic al fitxer `docker-stack.yml` amb la configuració de volums, configs, secrets i xarxa.

3. Crea el secret per a la passphrase de Borg:
   ```bash
   echo "una-passphrase-segura" | \
   docker secret create borg_passphrase -
   ```

4. Desplega l'stack i inicialitza el repositori de Borg:
   ```bash
   docker stack deploy -c docker-stack.yml myapp
   BORGMATIC_CONTAINER=$(docker ps -q -f name=myapp_borgmatic)
   docker exec -it ${BORGMATIC_CONTAINER} \
   borgmatic init --encryption repokey
   ```

5. Executa una còpia de seguretat manualment i verifica el resultat:
   ```bash
   BORGMATIC_CONTAINER=$(docker ps -q -f name=myapp_borgmatic)
   docker exec -it ${BORGMATIC_CONTAINER} borgmatic --verbosity 1
   docker exec -it ${BORGMATIC_CONTAINER} borgmatic list
   ```

6. Simula una pèrdua de dades:
   * Connecta a PostgreSQL i elimina algunes dades.
   * Restaura la base de dades des del backup:
   ```bash
   BORGMATIC_CONTAINER=$(docker ps -q -f name=myapp_borgmatic)
   docker exec -it ${BORGMATIC_CONTAINER} \
   borgmatic restore --database myapp
   ```

7. Fes còpia de seguretat de l'estat del clúster:
   ```bash
   systemctl stop docker
   tar -czf swarm-backup-$(date +%Y%m%d).tar.gz \
   /var/lib/docker/swarm
   systemctl start docker
   ```

8. Verifica que la programació automàtica funciona revisant els logs del servei:
   ```bash
   docker service logs myapp_borgmatic
   ```
