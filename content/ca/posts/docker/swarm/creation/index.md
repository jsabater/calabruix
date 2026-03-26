---
title: "Creació i gestió d'un clúster Docker Swarm"
date: 2026-01-31
lastmod: 2026-01-31
description: "Com inicialitzar un clúster Docker Swarm, afegir nodes i gestionar-los"
summary: "Com inicialitzar un clúster Docker Swarm, afegir nodes i gestionar-los"
categories: ["teaching"]
tags: ["docker", "swarm"]
series: ["Docker Swarm"]
series_order: 2
weight: 20
slug: creacio
---

Si estàs avesat a Docker Compose, potser esperes definir el clúster en un fitxer YAML i que Docker s'encarregui de configurar tots els nodes automàticament. Docker Swarm no funciona així.

Docker Swarm utilitza un model **imperatiu i distribuït**:

1. Et connectes a cada màquina, per SSH o consola.
2. Executes comandes (e.g., `docker swarm init`, `docker swarm join`).
3. Cada node es configura localment.

No existeix un fitxer central on declarar els nodes del clúster. El fitxer `docker-compose.yml` (o `stack.yml`) serveix per definir **serveis** que es despleguen sobre un clúster ja existent, no per crear el clúster en si.

Aquest model té l'avantatge de la simplicitat: no requereix un node de control extern, ni gestió centralitzada de claus SSH, ni dependències addicionals. Cada node només necessita Docker instal·lat i el token d'accés al clúster.

## Requisits previs

Abans de crear un clúster Docker Swarm, necessitam assegurar-nos de que complim els següents requisits:

* Tres o més màquines amb Docker instal·lat.
* Connectivitat de xarxa.
* Accés a Internet (opcional).

**Màquines**

Haurem de menester un mínim de **tres màquines**, físiques o virtuals, amb Docker Engine instal·lat. Per a aquest article, assumirem que disposem de tres màquines Debian o Ubuntu amb les següents característiques:

| Màquina | Rol previst | Adreça IP       | RAM | Disc | Serveis     |
|---------|:-----------:|-----------------|:---:|:----:|-------------|
| `node1` | Manager     | `192.168.1.101` | 1G  | 3G   | SSH, Docker |
| `node2` | Worker      | `192.168.1.102` | 1G  | 3G   | SSH, Docker |
| `node3` | Worker      | `192.168.1.103` | 1G  | 3G   | SSH, Docker |

> Adapta les adreces IP a la configuració de la teva xarxa local.

**Connectivitat**

Les màquines han d'estar connectades a la mateixa xarxa local i poder comunicar-se entre elles. Docker Swarm utilitza els següents ports:

| Port   | Protocol    | Funció                                  |
|:------:|:-----------:|:----------------------------------------|
| `2377` | `TCP`       | Comunicació de gestió del clúster (API) |
| `7946` | `TCP/UDP`   | Descobriment de nodes i gossip protocol |
| `4789` | `UDP`       | Tràfic de xarxa overlay (VXLAN)         |

> La xarxa *overlay* és una xarxa virtual que permet que els contenidors de diferents nodes es comuniquin entre ells com si estiguessin a la mateixa xarxa local. Docker Swarm utilitza [*](VXLAN) per encapsular el tràfic entre nodes a través de la xarxa física.

Podem usar l'eina `ping` per a verificar la correcta comunicació:

```bash
# Des de node1, verificam connectivitat amb els altres nodes
ping -c 3 192.168.1.102
ping -c 3 192.168.1.103
```

Si les màquines tenen el firewall activat (e.g., [UFW](https://launchpad.net/ufw) o [firewalld](https://firewalld.org/)), cal obrir aquests ports. En un entorn de laboratori amb el firewall desactivat, no és necessari fer res addicional.

Exemple amb UFW:

```bash
# SSH (mantenir accés remot)
sudo ufw allow 22/tcp

# Docker Swarm
sudo ufw allow 2377/tcp
sudo ufw allow 7946/tcp
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp

# Serveis web (si escau)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

{{< alert >}}
Assegura't d'obrir el port 22 (SSH) abans d'activar el firewall. Si no ho fas, perdràs l'accés remot a la màquina.
{{< /alert >}}

Uncomplicated Firewall aplica i persisteix aquestes regles immediatament, però l'activació es fa amb una comanda separada. Una vegada hagis configurat les regles, pots comprovar l'estat del tallafocs amb la següent comanda:

```bash
sudo ufw status
```

I pots activar-lo amb la següent:

```bash
sudo ufw enable
```

**Internet**

L'accés a Internet només és necessari per descarregar imatges de Docker Hub o altres registres remots. Si les imatges ja estan disponibles localment o disposeu d'un registre privat, el clúster pot funcionar completament offline, o dins una [*](DMZ).

## Inicialització

El primer pas és inicialitzar el swarm des de la màquina que serà el primer manager. Connecta't a `node1` i executa:

```bash
docker swarm init --advertise-addr 192.168.1.101
```

El paràmetre `--advertise-addr` indica quina adreça IP utilitzaran els altres nodes per connectar-se a aquest manager. És obligatori si la màquina té múltiples interfícies de xarxa.

La sortida serà semblant a: 

```text
Swarm initialized: current node (abc123def456) is now a manager.

To add a worker to this swarm, run the following command:

docker swarm join --token SWMTKN-1-0abc...xyz 192.168.1.101:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

{{< alert icon="circle-info" >}}
**Guarda el token!** El necessitaràs per afegir nodes obrers al clúster. Si el perds, el pots recuperar més endavant.
{{< /alert >}}

Un cop inicialitzat, podem verificar l'estat del clúster:

```bash
docker node ls
```

```text
ID               HOSTNAME   STATUS   AVAILABILITY   MANAGER STATUS   ENGINE VERSION
abc123def456 *   node1      Ready    Active         Leader           29.2.0
```

L'asterisc (`*`) indica el node on estem connectats. El camp `MANAGER STATUS` mostra `Leader` perquè és l'únic manager i, per tant, el líder del clúster.

## Afegir nodes

Per afegir els altres nodes seguirem aquestes tres passes:

1. Obtenir el token de gestor i el token d'obrer.
2. Afegir el node.
3. Verificar l'estat dels nodes.

> El token de worker és el mateix que ja hem obtingut com a part de la sortida de la comanda d'inicialització del swarm.

**Obtenir els tokens**

Docker Swarm utilitza **tokens** per autenticar els nodes que volen unir-se al clúster. Hi ha dos tokens diferents: un per a workers i un altre per a managers. Podem obtenir-los en qualsevol moment a través de les següents ordres:

```bash
# Token per afegir workers
docker swarm join-token worker

# Token per afegir managers
docker swarm join-token manager
```

Cada comanda mostra la instrucció completa que cal executar al node que es vol afegir:

```text
To add a worker to this swarm, run the following command:

docker swarm join --token SWMTKN-1-0abc...xyz 192.168.1.101:2377
```

**Afegir un worker**

Connecta't a `node2` i executa la comanda proporcionada:

```bash
docker swarm join --token SWMTKN-1-0abc...xyz 192.168.1.101:2377
```

Repeteix el procés a `node3`.

**Verificar els nodes**

Des del manager (`node1`), verifica que tots els nodes s'han unit correctament:

```bash
docker node ls
```

```text
ID               HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
abc123def456 *   node1      Ready     Active         Leader           29.2.0
def789ghi012     node2      Ready     Active                          29.2.0
ghi345jkl678     node3      Ready     Active                          29.2.0
```

Els workers no tenen valor a `MANAGER STATUS` perquè no participen en la gestió del clúster.

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart TB
    subgraph swarm["DOCKER SWARM (192.168.1.0/24)"]
        subgraph managers["MANAGERS"]
            M1["node1<br/>192.168.1.101<br/>(Leader)"]
        end
        
        managers -->|"Gestiona"| workers
        
        subgraph workers["WORKERS"]
            W1["node2<br/>192.168.1.102"]
            W2["node3<br/>192.168.1.103"]
            W1 ~~~ W2
        end
    end
{{< /mermaid >}}

## Gestió de tokens

Els tokens són elements crítics per a la seguretat del clúster. Permeten controlar qui pot unir-se al swarm i amb quin rol. A continuació veurem com gestionar-los de forma segura.

**Seguretat dels tokens**

Els tokens són secrets que permeten unir-se al clúster. Qualsevol persona amb accés al token pot afegir nodes. Per això, és important:

* No compartir els tokens públicament.
* Guardar-los en un lloc segur.
* Rotar els tokens periòdicament.
* Utilitzar tokens diferents per a workers i managers.

**Rotar els tokens**

Si sospites que un token ha estat compromès, pots generar-ne un de nou:

```bash
# Rotar el token de worker
docker swarm join-token --rotate worker

# Rotar el token de manager
docker swarm join-token --rotate manager
```

Després de rotar un token, l'antic deixa de ser vàlid immediatament. Els nodes ja units al clúster no es veuen afectats.

> Qualsevol manager pot rotar els tokens, no cal que sigui el `Leader`. El canvi es propaga automàticament a tots els managers a través del consens Raft.

## Inspecció de nodes

Un cop el clúster està en funcionament, necessitem eines per monitoritzar i obtenir informació dels nodes. Docker proporciona diverses comandes per inspeccionar l'estat i les característiques de cada node.

**Llistar nodes**

La comanda `docker node ls` mostra un resum de tots els nodes:

```bash
docker node ls
```

Els camps més importants són:

| Camp            | Descripció                                          |
|:----------------|:----------------------------------------------------|
| `ID`            | Identificador únic del node                         |
| `HOSTNAME`      | Nom de la màquina                                   |
| `STATUS`        | Estat de connexió (`Ready`, `Down`, `Disconnected`) |
| `AVAILABILITY`  | Disponibilitat (`Active`, `Pause`, `Drain`)         |
| `MANAGER STATUS`| Rol de manager (`Leader`, `Reachable`, o buit)      |

Valors dels camps de `docker node ls`:

| Camp           | Valor          | Significat                                                        |
|----------------|:--------------:|-------------------------------------------------------------------|
| Status         | `Ready`        | El node està connectat i respon correctament                      |
| Status         | `Down`         | El node no respon (apagat, sense xarxa, Docker aturat)            |
| Status         | `Disconnected` | El node ha perdut la connexió però encara no s'ha marcat com Down |
| Availability   | `Active`       | Accepta noves tasques amb normalitat                              |
| Availability   | `Pause`        | No accepta noves tasques, però manté les que ja té en execució    |
| Availability   | `Drain`        | No accepta tasques i evacua les actuals cap a altres nodes        |
| Manager status | `(buit)`       | El node és un worker, no participa en la gestió                   |
| Manager status | `Leader`       | Manager principal que coordina les decisions del clúster          |
| Manager status | `Reachable`    | Manager actiu que pot ser elegit Leader si l'actual falla         |
| Manager status | `Unreachable`  | Manager que no respon (els altres managers no el poden contactar) |

**Inspeccionar un node**

Per obtenir informació detallada d'un node:

```bash
docker node inspect node2
```

La sortida és un document JSON extens. Per veure només informació específica:

```bash
# Veure l'adreça IP del node
docker node inspect --format '{{.Status.Addr}}' node2

# Veure els recursos disponibles
docker node inspect --format '{{.Description.Resources}}' node2
```

**Etiquetes de nodes**

Les etiquetes (*labels*) permeten classificar nodes per característiques com ubicació, tipus de maquinari, o funció. Això és útil per desplegar serveis en nodes específics.

```bash
# Afegir una etiqueta
docker node update --label-add zona=mallorca node2
docker node update --label-add zona=menorca node3

# Afegir múltiples etiquetes
docker node update --label-add tipus=ssd --label-add rack=1 node2
```

Per veure les etiquetes d'un node:

```bash
docker node inspect --format '{{.Spec.Labels}}' node2
```

```text
map[zona:mallorca tipus:ssd rack:1]
```

Més endavant veurem com utilitzar aquestes etiquetes per controlar on es despleguen els serveis.

## Promoció i degradació

La topologia del clúster no és estàtica. Podem canviar el rol dels nodes segons les necessitats: promocionar workers a managers per augmentar la tolerància a fallades, o degradar managers quan ja no siguin necessaris.

**Convertir un worker en manager**

En entorns de producció, és recomanable tenir múltiples managers per garantir l'alta disponibilitat. Podem promocionar un worker a manager:

```bash
docker node promote node2
```

Verifiquem el canvi:

```bash
docker node ls
```

```text
ID               HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
abc123def456 *   node1    Ready     Active         Leader           29.2.0
def789ghi012     node2    Ready     Active         Reachable        29.2.0
ghi345jkl678     node3    Ready     Active                          29.2.0
```

Ara `node2` mostra `Reachable` com a `MANAGER STATUS`, indicant que és un manager actiu però no el líder.

**Convertir un manager en worker**

El procés invers és degradar un manager a worker:

```bash
docker node demote node2
```

{{< alert >}}
**Atenció amb el quòrum!** No degradis managers si això redueix el nombre de managers per sota del mínim necessari per mantenir el quòrum.
{{< /alert >}}

**El quòrum de managers**

El quòrum és el nombre mínim de managers que han d'estar disponibles per prendre decisions. Es calcula com `(n/2) + 1`, on `n` és el nombre total de managers:

| Managers totals | Quòrum mínim | Tolerància a fallades |
|:---------------:|:------------:|:---------------------:|
| 1               | 1            | 0                     |
| 2               | 2            | 0                     |
| 3               | 2            | 1                     |
| 5               | 3            | 2                     |
| 7               | 4            | 3                     |

Per això es recomana sempre un nombre **senar** de managers: 1, 3, 5 o 7.

## Gestionar la disponibilitat

Podem canviar la disponibilitat d'un node sense treure'l del clúster. Existeixen tres estats de disponibilitat:

| Estat    | Descripció                                               |
|:---------|:---------------------------------------------------------|
| `active` | El node accepta noves tasques amb normalitat             |
| `pause`  | El node no accepta noves tasques, però manté les actuals |
| `drain`  | El node no accepta tasques i evacua les que té           |

El mode `Drain` és útil per fer manteniment en un node sense interrompre els serveis:

```bash
docker node update --availability drain node3
```

Les tasques que s'executaven a `node3` es redistribuiran automàticament als altres nodes disponibles.

Un cop acabat el manteniment, podem tornar el node a l'estat actiu:

```bash
docker node update --availability active node3
```

## Eliminar nodes

Per treure un node del clúster, primer cal executar des del propi node:

```bash
# Des de node3
docker swarm leave
```

Si el node és un manager, cal forçar la sortida:

```bash
docker swarm leave --force
```

Després que un node hagi sortit (o si està desconnectat), el podem eliminar de la llista:

```bash
# Des de node1 (manager)
docker node rm node3
```

Si el node encara està actiu, cal forçar l'eliminació:

```bash
docker node rm --force node3
```

## Resum

| Comanda                                    | Funció                                      |
| :----------------------------------------- | :------------------------------------------ |
| `docker swarm init --advertise-addr IP`    | Inicialitza el swarm                        |
| `docker swarm join --token TOKEN IP:2377`  | Uneix un node al swarm                      |
| `docker swarm join-token worker`           | Mostra el token per afegir workers          |
| `docker swarm join-token manager`          | Mostra el token per afegir managers         |
| `docker swarm join-token --rotate worker`  | Genera un nou token de worker               |
| `docker swarm leave`                       | Surt del swarm (des del node)               |
| `docker node ls`                           | Llista els nodes del clúster                |
| `docker node inspect NODE`                 | Mostra informació detallada d'un node       |
| `docker node update --label-add KEY=VAL`   | Afegeix una etiqueta a un node              |
| `docker node update --availability STATE`  | Canvia la disponibilitat (`active`/`drain`) |
| `docker node promote NODE`                 | Promociona un worker a manager              |
| `docker node demote NODE`                  | Degrada un manager a worker                 |
| `docker node rm NODE`                      | Elimina un node del clúster                 |

## Exercici pràctic

L'objectiu d'aquest exercici pràctic és crear un clúster Docker Swarm amb 3 nodes i practicar les operacions bàsiques de gestió.

Requisits:

* 3 màquines (virtuals o físiques) amb Docker instal·lat.
* Connectivitat de xarxa entre elles.
* Accés SSH o terminal a cada màquina.

Tasques:

1. **Preparació**:
   * Anota les adreces IP de les tres màquines.
   * Verifica la connectivitat entre elles amb `ping`.
   * Verifica que Docker està instal·lat i funcionant a cada màquina (`docker version`).

2. **Inicialització**:
   * Inicialitza el swarm a la primera màquina.
   * Guarda el token de worker que es mostra.

3. **Afegir nodes**:
   * Uneix les altres dues màquines com a workers.
   * Verifica que els tres nodes apareixen amb `docker node ls`.

4. **Etiquetes**:
   * Afegeix una etiqueta `environment` a tots els nodes.
   * Afegeix l'etiqueta `disk` al segon node.
   * Afegeix l'etiqueta `cpu` al tercer node.
   * Verifica les etiquetes amb `docker node inspect`.

5. **Promoció**:
   * Promociona el segon o el tercer node a manager.
   * Verifica que ara hi ha dos managers.

6. **Manteniment**:
   * Posa el node que no és gestor en mode `Drain`.
   * Verifica l'estat amb `docker node ls`.
   * Torna'l a posar en mode `Active`.

7. **Neteja**:
   * Degrada el segon node gestor a obrer.
   * Fes que el segon o el tercer node surti del clúster.
   * Elimina'l de la llista de nodes.
