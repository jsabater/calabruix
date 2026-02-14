---
title: "Persistència de dades a Swarm"
date: 2026-01-31
lastmod: 2026-01-31
description: "Reptes de la persistència en entorns distribuïts, volums locals i estratègies per a serveis amb estat"
summary: "Reptes de la persistència en entorns distribuïts, volums locals i estratègies per a serveis amb estat"
categories: ["teaching"]
tags: ["docker", "swarm"]
series: ["Docker Swarm"]
series_order: 6
weight: 60
slug: persistencia
---

Quan fas feina amb Docker en una sola màquina, la persistència de dades és relativament senzilla: crees un volum i el muntes al contenidor. Si el contenidor es reinicia o es recrea, les dades continuen al volum, que resideix al mateix *host*.

A Docker Swarm, la situació es complica car les tasques es poden executar a qualsevol node del clúster, i si una tasca es mou a un altre node (per una actualització, una fallada, o un reequilibri), el volum local del node original no és accessible des del nou node.

## El repte

El nivell de complexitat augmenta notablement amb la persistència distribuïda. Imagina aquest escenari:

1. Crees un servei `database` amb un volum per a les dades.
2. La tasca s'executa a `node1`, on es crea el volum amb les dades.
3. `node1` falla i Swarm mou la tasca a `node2`.
4. A `node2` es crea un volum nou, però buit. Les dades s'han perdut.

Aquest és el problema fonamental: **els volums de Docker són locals a cada node**. Docker Swarm no proporciona replicació de volums entre nodes de forma nativa.

## Tipus de muntatge

Docker Swarm suporta els mateixos tipus de muntatge que Docker tradicional:

| Tipus    | Descripció                                | Persistència      |
|:---------|:------------------------------------------|:------------------|
| `volume` | Volum gestionat per Docker                | Local al node     |
| `bind`   | Directori del sistema de fitxers del host | Local al node     |
| `tmpfs`  | Sistema de fitxers temporal a memòria     | Es perd en aturar |

Docker Swarm ens permet muntar un volum durant la creació del servei:

```bash
docker service create \
  --name database \
  --mount type=volume,source=db-data,target=/var/lib/postgresql \
  postgres:18
```

En comptes de muntar un volum, podem muntar un directori del *host* (*bind mount*):

```bash
docker service create \
  --name webserver \
  --mount type=bind,source=/var/www/html,target=/usr/local/apache2/htdocs \
  httpd:2.4
```

I, finalment, també podem muntar un sistema de fitxers temporal:

```bash
docker service create \
  --name cache \
  --mount type=tmpfs,target=/tmp/cache,tmpfs-size=100M \
  redis:7-alpine
```

## Estratègies

Com que Docker Swarm no resol la persistència distribuïda de forma nativa, cal adoptar estratègies segons el cas d'ús.

### Restringir el servei

La solució més senzilla és forçar que el servei s'executi sempre al mateix node, on resideix el volum. Això es fa amb restriccions (*constraints*). Aquesta restricció la podem implementar, per exemple, a través d'etiquetes.

En primer lloc, afegiríem una etiqueta al node que té l'emmagatzematge:

```bash
docker node update --label-add storage=ssd node1
```

I, després, crearíem el servei restringit a aquest node:

```bash
docker service create \
  --name database \
  --constraint 'node.labels.storage==ssd' \
  --mount type=volume,source=db-data,target=/var/lib/postgresql \
  postgres:18
```

Avantatges:

* Senzill d'implementar.
* No requereix infraestructura addicional.

Inconvenients:

* Si el node falla, el servei no es pot moure automàticament.
* No hi ha alta disponibilitat real.

Podem crear les etiquetes personalitzades que ens siguin més convenients, e.g., `node.labels.gpu==true`. En termes generals, altres opcions per aplicar restriccions passen per usar atributs del node:

| Constraint           | Exemple                     | Descripció                     |
|----------------------|-----------------------------|--------------------------------|
| `node.id`            | `node.id==abc123def456`     | Identificador únic del node    |
| `node.hostname`      | `node.hostname==node1`      | Nom del host                   |
| `node.role`          | `node.role==manager`        | Rol: `manager` o `worker`      |
| `node.platform.os`   | `node.platform.os==linux`   | Sistema operatiu               |
| `node.platform.arch` | `node.platform.arch==amd64` | Arquitectura: `amd64`, `arm64` |

### Emmagatzematge compartit

Muntar un sistema de fitxers compartit a tots els nodes permet que qualsevol node accedeixi a les mateixes dades. Les opcions més habituals són [*](NFS) i GlusterFS.

**NFS (Network File System)**

NFS és un protocol estàndard per compartir directoris a través de la xarxa. Un servidor exporta un directori i els clients el munten com si fos local. És senzill de configurar però té un punt únic de fallada: si el servidor NFS cau, tots els serveis que en depenen deixen de funcionar.

En primer lloc, cal muntar el recurs NFS a tots els nodes:

```bash
# A cada node
sudo mount -t nfs servidor-nfs:/exports/postgres /mnt/postgres
```

Després, usaríem un *bind mount* al servei:

```bash
docker service create \
  --name database \
  --mount type=bind,source=/mnt/postgres,target=/var/lib/postgresql \
  postgres:18
```

**GlusterFS**

GlusterFS és un sistema de fitxers distribuït de codi obert que agrega l'emmagatzematge de múltiples nodes en un sol espai unificat. A diferència de NFS, les dades es repliquen entre els nodes participants, oferint tolerància a fallades.
Funcionament bàsic:

* Cada node aporta un directori local (*brick*) al clúster GlusterFS.
* GlusterFS combina aquests *bricks* en un volum distribuït o replicat.
* Els nodes munten el volum GlusterFS i hi accedeixen de forma transparent.

Una configuració de GlusterFS amb els 3 nodes del clúster passaria, en primer lloc, per instal·lar els paquets necessaris:

```bash
# A cada node
apt install glusterfs-server
systemctl enable --now glusterd
```

Tot seguit, des de node1, hem d'afegir els altres nodes al clúster GlusterFS:

```bash
gluster peer probe node2
gluster peer probe node3
```

Després crearem un directori `brick` a cada node, que serà usat per guardar les dades:

```bash
mkdir --parents /srv/brick
```

Ja podem crear i iniciar el volum replicat. Des del `node1`:

```bash
gluster volume create swarm-data replica 3 \
  node1:/srv/brick \
  node2:/srv/brick \
  node3:/srv/brick
gluster volume start swarm-data
```

Finalment, muntarem el volum a cada node:

```bash
mkdir --parents /mnt/swarm-data
mount -t glusterfs localhost:/swarm-data /mnt/swarm-data
```

Un cop muntat, es pot usar amb Docker igual que NFS:

```bash
docker service create \
  --name database \
  --mount type=bind,source=/mnt/swarm-data/uploads,target=/app/uploads \
  myapp/webapp
```

Amb `replica 3` durant la creació, cada fitxer es guarda a tots tres nodes. Si un node falla, les dades segueixen disponibles als altres dos.

Comparativa entre NFS i GlusterFS:

| Aspecte               | NFS                           | GlusterFS                       |
|-----------------------|-------------------------------|---------------------------------|
| Arquitectura          | Centralitzada (servidor únic) | Distribuïda (tots els nodes)    |
| Tolerància a fallades | No (punt únic de fallada)     | Sí (replicació entre nodes)     |
| Complexitat           | Baixa                         | Mitjana                         |
| Rendiment             | Bo per a lectures             | Bo per a lectures i escriptures |
| Ús de disc            | Només al servidor             | A tots els nodes participants   |

**Adequació segons el cas d'ús**

Ni NFS ni GlusterFS són adequats per a qualsevol tipus de dades. La documentació oficial de GlusterFS indica explícitament que no suporta dades estructurades com bases de dades SQL en execució, tot i que sí que es pot usar per fer-ne backups. La taula següent resumeix els casos d'ús més comuns:

| Cas d'ús                    | NFS        | GlusterFS  |
|-----------------------------|------------|------------|
| Fitxers estàtics web        | Adequat    | Adequat    |
| Imatges pujades per usuaris | Adequat    | Adequat    |
| Logs d'aplicació            | Adequat    | Adequat    |
| Backups de bases de dades   | Adequat    | Adequat    |
| Sessions web en fitxers     | Adequat    | Adequat    |
| Bases de dades              | No adequat | No adequat |
| Caché (persistència)        | No adequat | No adequat |
| Cues de missatges           | No adequat | No adequat |
| Codi d'aplicació            | No adequat | No adequat |

Les bases de dades requereixen garanties estrictes de sincronització (`fsync`) i bloqueig que NFS i GlusterFS no poden oferir de forma fiable. Per a aquests casos, les opcions recomanades són:

* Usar emmagatzematge local amb restricció de node (estratègia 1).
* Configurar replicació a nivell d'aplicació (estratègia 4): PostgreSQL amb *streaming replication*, Redis amb Sentinel, etc.

**Altres opcions**

[JuiceFS](https://github.com/juicedata/juicefs) és un sistema de fitxers distribuït de codi obert que separa les metadades de les dades. Les metadades s'emmagatzemen en bases de dades com Redis, mentre que les dades es guarden en sistemes d'emmagatzematge d'objectes com S3 o MinIO. Aquesta arquitectura permet escalar les dades de forma independent de les metadades i ofereix compatibilitat POSIX completa. És una alternativa interessant per a entorns que ja disposen d'emmagatzematge d'objectes.

**Avantatges i inconvenients**

Avantatges de l'emmagatzematge compartit:

* Les dades són accessibles des de qualsevol node.
* El servei es pot moure entre nodes sense perdre dades.

Inconvenients:

* Requereix infraestructura addicional i configuració prèvia.
* El rendiment depèn de la xarxa.
* NFS i GlusterFS poden no ser adequats per a totes les bases de dades amb patrons d'escriptura intensiva o requisits estrictes de bloqueig.

Una altra opció és , un sistema de fitxers distribuït que funciona separant les metadades, que s'emmagatzemen en bases de dades com Redis, de les dades reals, que es guarden en sistemes d'emmagatzematge d'objectes com S3.

### Plugins de volums

Docker permet estendre el sistema de volums mitjançant plugins. Un plugin de volum s'integra directament amb Docker i gestiona la creació, muntatge i desmuntatge de volums de forma transparent. Quan una tasca es mou a un altre node, el plugin s'encarrega d'acoblar el volum al nou node automàticament.

Malauradament, aquest ecosistema ha patit un "esdeveniment d'extinció" massiu en els darrers anys a mesura que la indústria s'ha decantat cap a Kubernetes. La majoria de complements clàssics (REX-Ray, Convoy, Flocker, etc.) varen deixar de rebre manteniment i són incompatibles amb les versions modernes de Docker (específicament, a partir de la versió 23).

A mode de referència, la instal·lació i configuració d'un plugin de volum de Docker Swarm seguia aquestes tres passes:

* Instal·lar el plugin.
  ```bash
  docker plugin install nom-del-plugin
  ```
* Crear un volum gestionat pel plugin.
  ```bash
  docker volume create \
    --driver nom-del-plugin \
    --opt size=20 \
    uploads
  ```
* Usar el volum normalment.
  ```bash
  docker service create \
    --name database \
    --mount type=volume,source=uploads,target=/app/uploads \
    myapp/webapp
  ```

El panorama ha canviat, passant del tenir *plugins* natius de Docker a tenir ponts CSI (Container Storage Interface).

### Controladors CSI

A partir de la versió 23, Docker Engine va introduir suport per a controladors *Container Storage Interface* mitjançant una funcionalitat anomenada *Cluster Volumes*. Això permet a Docker Swarm usar els mateixos controladors d'emmagatzematge que Kubernetes, obrint la porta a solucions d'emmagatzematge més modernes i activament mantingudes.

A dia d'avui, en comptes d'instal·lar un *plugin* de Docker amb `docker plugin install`, s'instal·la un CSI com a servei del Swarm i es creeen els volums usant el controlador de CSI, amb el paràmetre `--driver`.

[Democratic-CSI](https://github.com/democratic-csi/democratic-csi) la implementació CSI de codi obert més popular per a Docker Swarm. Proporciona emmagatzematge persistent a través de protocols com [*](iSCSI), [*](NFS) i [*](SMB), usant backends basats en [*](ZFS) (TrueNAS, FreeNAS, ZFS on Linux).

Requisits:

* Un backend d'emmagatzematge compatible (TrueNAS, ZFS on Linux, etc.).
* El servei `iscsid` en execució a cada node (per a iSCSI).
* Docker Engine 23 o superior.

La configuració de Democratic-CSI consta de tres parts:

* La configuració del controlador.
* El desplegament del servei.
* La creació de volums.

**Configuració del controlador**

Es crea un fitxer de configuració que defineix com connectar-se al backend d'emmagatzematge. Per exemple, per a un servidor TrueNAS amb NFS:

```yaml
# /etc/democratic-csi/config.yaml
driver: freenas-nfs
httpConnection:
    protocol: https
    host: truenas.local
    port: 443
    apiKey: YOUR_API_KEY
    allowInsecure: true
nfs:
    shareHost: truenas.local
    shareAllow: "192.168.1.0/24"
zfs:
    datasetParentName: tank/docker/volumes
    datasetEnableQuotas: true
```

**Desplegament del servei**

Democratic-CSI s'executa com un servei global (una instància per node) al clúster:

```bash
docker service create \
  --name democratic-csi \
  --mode global \
  --mount type=bind,source=/etc/democratic-csi,target=/config \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  --mount type=bind,source=/run/docker/plugins,target=/run/docker/plugins \
  --mount type=bind,source=/var/lib/democratic-csi,target=/var/lib/csi \
  democraticcsi/democratic-csi:latest --config /config/config.yaml
```

**Creació de volums**

Un pic el servei està en execució, es poden crear volums CSI amb `docker volume create` especificant el controlador i les opcions:

```bash
docker volume create \
  --driver democratic-csi \
  --opt size=10G \
  webapp-uploads
```

I llavors usar-los en serveis:

```bash
docker service create \
  --name webapp \
  --mount type=volume,source=webapp-uploads,target=/app/uploads \
  myapp/webapp
```

**Funcionament**

Quan una tasca es mou a un altre node:

* El controlador CSI desmunta el volum del node original.
* El controlador crea o munta el volum al nou node.
* La tasca s'inicia amb accés a les mateixes dades.

Aquest comportament és similar al dels plugins clàssics, però usant l'estàndard CSI de la indústria.

**Complexitat addicional**

La complexitat addicional és el cost de l'estandardització. Els plugins clàssics de Docker eren senzills perquè estaven dissenyats específicament per a Docker, amb una API propietària. CSI, en canvi, és un estàndard de la indústria que va ser dissenyat pensant en Kubernetes, on els controladors s'executen com a pods dins el clúster. Docker Swarm ha hagut d'adaptar-se a aquest estàndard, i el resultat és una integració manco elegant.

Quan té sentit usar Democratic-CSI?

* Si ja comptam amb un [*](NAS) amb [*](ZFS) (TrueNAS, Synology amb ZFS, servidor amb ZoL).
* Vols emmagatzematge de blocs per a bases de dades.
* Vols gestió dinàmica de volums (crear/eliminar volums sense tocar el NAS manualment).

Quan no té sentit?

* No comptam amb un backend ZFS dedicat.
* Volem replicació de dades entre nodes del Swarm (això ho fan GlusterFS, Ceph, DRBD, no CSI).
* L'entorn és senzill i NFS ja cobreix les necessitats.

> Podem usar un emmagatzematge distribuït com GlusterFS o un emmagatzematge compartit com NFS per guardar fitxers estàtics, logs, còpies de seguretat, etc. Si tenim necessitat de fer-ho amb blocs, usarem iSCSI via CSI, el que m'obre les portes de poder guardar-hi la base de dades de PostgreSQL o les tasques a disc de RabbitMQ o Redis/Valkey.

### Replicació

Algunes aplicacions gestionen la seva pròpia replicació de dades. En aquest cas, cada rèplica pot tenir el seu volum local, i l'aplicació s'encarrega de mantenir les dades sincronitzades.

Exemples:

* PostgreSQL amb Patroni o replicació en streaming.
* MariaDB amb replicació master-slave o *group replication*.
* MongoDB amb replica sets.
* Elasticsearch amb sharding i rèpliques.
* Redis amb Sentinel o cluster mode.

**Exemple conceptual: Redis amb Sentinel**

Redis Sentinel és la solució recomanada pels desenvolupadors de Redis per gestionar l'alta disponibilitat. També està disponible amb Valkey i el seu funcionament és idèntic. Sentinel té tres funcions clau:

* Monitorització: Comprova constantment si les instàncies mestres i rèpliques funcionen.
* Notificació: Avisa als administradors o altres aplicacions si alguna cosa va malament.
* Recuperació automàtica (*failover*): Si el node mestre cau, Sentinel promou automàticament una de les rèpliques perquè passi a ser el nou primari, i reconfigura la resta de rèpliques per obeir-lo.

Començaríem creant el servei de Redis amb el primari:

```bash
docker service create \
  --name redis-master \
  --constraint 'node.labels.redis==master' \
  --mount type=volume,source=redis-data,target=/data \
  redis:7-alpine
```

I acabaríem configurant els servei secundari, en aquest cas amb dues rèpliques:

```bash
docker service create \
  --name redis-slave \
  --replicas 2 \
  redis:7-alpine redis-server --slaveof redis-master 6379
```

Avantatges:

* Alta disponibilitat real.
* Tolerància a fallades de nodes.

Inconvenients:

* Complexitat de configuració.
* Cada aplicació té el seu mecanisme de replicació.

## Serveis amb i sense estat

La distinció entre serveis **stateful** (amb estat) i **stateless** (sense estat) és fonamental per decidir l'estratègia de persistència.

El serveis sense estat (stateless) no guarden dades persistents. Tota la informació necessària ve de peticions externes o de serveis de dades separats. Es poden escalar i moure lliurement. Exemples: servidors web, APIs, proxies inversos, processadors de tasques.

Un servidor web sense estat és fàcil de gestionar:

```bash
docker service create --name webserver --replicas 5 nginx:1.26
```

En canvi, els serveis amb estat (stateful) guarden dades que han de persistir entre reinicis o moviments. Per tant, requereixen estratègies especials de persistència. Exemples: bases de dades, cues de missatges, sistemes de fitxers.

Una base de dades requereix més planificació:

```bash
docker service create \
  --name database \
  --replicas 1 \
  --constraint 'node.labels.storage==ssd' \
  --mount type=volume,source=db-data,target=/var/lib/postgresql \
  postgres:18
```

Per tant, sempre que sigui possible, dissenya els teus serveis perquè siguin stateless, delegant l'estat a serveis especialitzats (bases de dades, caches, cues) que puguis gestionar amb les estratègies adequades.

Per exemple, pots dissenyar la teva aplicació web perquè utilitzi un magatzem d'objectes compatible amb S3 per als fitxers estàtics i les imatges.

## Còpies de seguretat

Independentment de l'estratègia de persistència, els *backups* són essencials. Si escau, pots fer còpia de seguretat de volums locals des del node on resideix el volum:

```bash
docker run --rm \
  -v db-data:/source:ro \
  -v /backups:/backup \
  alpine tar czf /backup/db-data-$(date +%Y%m%d).tar.gz -C /source .
```

Aquesta comanda crea un arxiu comprimit `.tar.gz` amb els continguts del volum de Docker anomenat `db-data` i el guarda al directori local `/backups`. Ho fa aixecant un contenidor temporal molt lleuger només amb el propòsit d'executar l'ordre `tar`, i llavors immediatament esborrant el contenidor una vegada ha acabat de fer la còpia. Com a mesura de seguretat, munta el volum en mode només lectura per evitar que el procés de *backup* modifiqui accidentalment les dades al volum de base dades.

De totes formes, per a les bases de dades és millor usar les eines natives, que garanteixen consistència i permeten fer-ho mentres l'aplicació s'està executant:

```bash
# PostgreSQL
docker exec database pg_dump -U postgres -F c mydb > backup.pgc

# MariaDB
docker exec database mysqldump -u root -p mydb > backup.sql

# Redis
docker exec redis redis-cli BGSAVE
```

És clar que l'objectiu és l'automatització d'aquests processos, per exemple mitjançant serveis com `cron`, perquè executi backups periòdicament. Eines com [Borg Backup](https://www.borgbackup.org/) són útils per a backups incrementals i xifrats.

## Resum

| Comanda / Opció                                       | Funció                                         |
|:------------------------------------------------------|:-----------------------------------------------|
| `--mount type=volume,source=NOM,target=PATH`          | Munta un volum gestionat per Docker            |
| `--mount type=bind,source=PATH_HOST,target=PATH_CONT` | Munta un directori del host                    |
| `--mount type=tmpfs,target=PATH`                      | Munta un sistema de fitxers temporal a memòria |
| `--constraint 'node.labels.KEY==VALUE'`               | Restringeix el servei a nodes amb l'etiqueta   |
| `docker volume create --driver DRIVER NOM`            | Crea un volum amb un driver específic          |
| `docker volume ls`                                    | Llista els volums                              |
| `docker volume inspect NOM`                           | Mostra detalls d'un volum                      |
| `docker volume rm NOM`                                | Elimina un volum                               |

## Exercici pràctic

L'objectiu d'aquest exercici és comprendre els reptes de la persistència a Docker Swarm i practicar les estratègies bàsiques.

Requisits:

* Un clúster Docker Swarm amb almanco 3 nodes.
* Connectivitat de xarxa entre els nodes.

Tasques:

1. **Crear un servei amb volum sense restriccions**:
   * Crea un servei `notes` amb la imatge `caddy:2-alpine` i un volum muntat a `/data`.
   * No afegeixis cap restricció.
   * Identifica a quin node s'executa amb `docker service ps notes`.
   * Accedeix al contenidor i crea un fitxer a `/data`:
     ```bash
     docker exec -it $(docker ps -q -f name=notes) sh
     echo "Dades importants" > /data/nota.txt
     exit
     ```

2. **Simular una fallada de node**:
   * Posa el node on s'executa `notes` en mode `drain`:
     ```bash
     docker node update --availability drain NODE
     ```
   * Observa com la tasca es mou a un altre node.
   * Accedeix al nou contenidor i comprova si el fitxer existeix:
     ```bash
     docker exec -it $(docker ps -q -f name=notes) cat /data/nota.txt
     ```
   * El fitxer no existirà perquè el volum és local al node original.

3. **Restaurar el node**:
   * Torna a posar el node en mode `active`:
     ```bash
     docker node update --availability active NODE
     ```

4. **Crear un servei restringit a un node**:
   * Afegeix una etiqueta al node que vulguis usar:
     ```bash
     docker node update --label-add storage=local node1
     ```
   * Elimina el servei `notes` anterior.
   * Crea'l de nou amb una restricció:
     ```bash
     docker service create \
       --name notes \
       --constraint 'node.labels.storage==local' \
       --mount type=volume,source=notes-data,target=/data \
       caddy:2-alpine
     ```
   * Crea un fitxer a `/data` com abans.

5. **Comprovar la persistència**:
   * Força una actualització del servei (per recrear la tasca):
     ```bash
     docker service update --force notes
     ```
   * Verifica que el fitxer segueix existint.
   * Això funciona perquè la tasca es recrea al mateix node, on resideix el volum.

6. **Explorar el problema de la restricció**:
   * Posa el node restringit en mode `drain`.
   * Observa què passa amb el servei (no es pot replanificar a cap altre node).
   * Torna el node a mode `active`.

7. **Neteja**:
   * Elimina el servei `notes`.
   * Elimina l'etiqueta del node:
     ```bash
     docker node update --label-rm storage node1
     ```
   * Elimina els volums creats:
     ```bash
     docker volume rm notes-data
     ```
