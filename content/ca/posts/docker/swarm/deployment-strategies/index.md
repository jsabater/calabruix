---
title: "Estratègies de desplegament avançades"
date: 2026-03-01
lastmod: 2026-03-01
description: "Rolling updates, desplegaments Blue-Green, rollback i gestió de fallades"
summary: "Rolling updates, desplegaments Blue-Green, rollback i gestió de fallades"
categories: ["teaching"]
tags: ["docker", "swarm", "deployment", "blue-green", "rollback"]
series: ["Docker Swarm"]
series_order: 11
weight: 110
slug: estrategies-desplegament
---

En articles anteriors hem desplegat aplicacions amb Docker Swarm usant l'estratègia per defecte: el *rolling update*. En aquest article explorarem amb més profunditat aquesta estratègia i n'introduirem una altra de molt popular: el *desplegament Blue-Green*. També veurem com fer *rollback* quan un desplegament falla.

## Rolling updates

El *rolling update* és l'estratègia per defecte de Docker Swarm. Consisteix en actualitzar les tasques d'un servei de forma progressiva, substituint les antigues per les noves de manera gradual, sense interrompre el servei.

A l'article [Actualització i manteniment de serveis]({{< relref "/posts/docker/swarm/update/">}}) vàrem veure una configuració bàsica:

```yaml
services:
  web:
    image: myuser/myapp:${VERSION:-latest}
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
```

Aquesta configuració indica que:

* `parallelism: 1`: Actualitza una tasca a la vegada.
* `delay: 10s`: Espera 10 segons entre cada actualització.
* `order: start-first`: Crea la tasca nova abans d'aturar l'antiga.

### Paràmetres avançats

Docker Swarm ofereix més paràmetres per controlar el comportament dels rolling updates:

| Paràmetre           | Descripció                                                | Valor per defecte |
|:--------------------|:----------------------------------------------------------|:------------------|
| `parallelism`       | Nombre de tasques a actualitzar simultàniament            | 1                 |
| `delay`             | Temps d'espera entre actualitzacions                      | 0s                |
| `order`             | Ordre d'operacions: `stop-first` o `start-first`          | `stop-first`      |
| `failure_action`    | Acció si falla: `pause`, `continue` o `rollback`          | `pause`           |
| `monitor`           | Temps per monitoritzar l'estat després de l'actualització | 5s                |
| `max_failure_ratio` | Percentatge màxim de fallades tolerat                     | 0                 |

Exemple complet:

```yaml
services:
  web:
    image: myuser/myapp:${VERSION:-latest}
    deploy:
      replicas: 6
      update_config:
        parallelism: 2
        delay: 10s
        order: start-first
        failure_action: rollback
        monitor: 30s
        max_failure_ratio: 0.2
```

Aquesta configuració:

* Actualitza 2 tasques simultàniament (`parallelism: 2`).
* Espera 10 segons entre cada lot de 2 tasques.
* Crea les tasques noves abans d'aturar les antigues.
* Monitoritza cada tasca durant 30 segons després d'iniciar-la.
* Si més del 20% de les tasques fallen, fa rollback automàticament.
* Si una tasca falla però no se supera el 20%, continua amb les següents.

### Ordre d'operacions

La diferència entre `stop-first` i `start-first` és significativa. Amb `stop-first`, valor per defecte, el procés d'actualització es comportarà de la següent forma en el temps:

```
Temps →
Tasca 1: [████ antiga ████]              [████ nova ████]
Tasca 2:                   [████ antiga ████]              [████ nova ████]
Tasca 3:                                      [████ antiga ████]              [████ nova ████]
                           ↑              ↑
                     Manco capacitat durant la transició
```

És a dir, Docker Swarm:

* Primer atura la tasca antiga (envia `SIGTERM`, espera, envia `SIGKILL` si cal).
* Programa la nova tasca a un node.
* Baixa la imatge si no existeix al node.
* Inicia la nova tasca.
* Espera a que el contenidor estigui en estat `running`, o passi el `healthcheck` si n'hi ha.
* Aplica el valor del paràmetre `delay`.
* Passa a la següent tasca.

Durant la transició, hi ha manco capacitat disponible. Aquesta estratègia és útil quan els recursos són limitats.

En canvi, amb `start-first`, la cronologia d'esdeveniments seria la següent:

```
Temps →
Tasca 1: [████ antiga ████]
         [████ nova ████████████████████████████]
Tasca 2:      [████ antiga ████]
              [████ nova ████████████████████████████]
Tasca 3:           [████ antiga ████]
                   [████ nova ████████████████████████████]
                   ↑
             Més capacitat durant la transició
```

* Primer inicia la tasca nova.
* Espera a que la tasca estigui llesta (estat `running` o passi `healthcheck`, si escau).
* Atura la tasca antiga.
* Aplica el valor del paràmetre `delay`.
* Passa a la següent tasca.

Durant la transició, hi ha més capacitat disponible. Per tant, requereix recursos addicionals temporalment. Aquesta estratègia és útil per a serveis crítics on no es pot perdre capacitat.

### Monitorització

Per seguir el progrés d'un *rolling update* podem combinar les comandes `watch` i `docker`. Per veure l'estat de les tasques en temps quasi real:

```bash
watch docker stack ps myapp
```

O, si tenim interès en un servei concret:

```bash
watch docker service ps myapp_web
```

La sortida mostra l'estat de cada tasca:

```
ID             NAME              IMAGE                   NODE    STATE
abc123         myapp_web.1       myuser/myapp:1.2.0     node1   Running
def456         myapp_web.2       myuser/myapp:1.2.0     node2   Running
ghi789         myapp_web.3       myuser/myapp:1.1.0     node3   Running
jkl012          \_myapp_web.3    myuser/myapp:1.1.0     node3   Shutdown
```

## Rollback

Quan un desplegament falla o introdueix errors, cal tornar a la versió anterior. Docker Swarm ofereix dues maneres de fer-ho.

* Rollback automàtic.
* Rollback manual.

Si hem configurat `failure_action: rollback`, Swarm farà rollback automàticament quan detecti fallades:

```yaml
deploy:
  update_config:
    failure_action: rollback
    monitor: 30s
    max_failure_ratio: 0.2
```

Amb aquesta configuració, si més del 20% de les tasques fallen dins els primers 30 segons, Swarm reverteix automàticament a la versió anterior.

En canvi, per fer rollback manualment usam la comanda `docker service rollback`:

```bash
docker service rollback myapp_web
```

Aquesta comanda reverteix el servei a la configuració anterior, incloent la imatge, variables d'entorn i qualsevol altre paràmetre que s'hagi canviat.

Per veure l'historial de versions d'un servei podem usar la següent ordre:

```bash
docker service inspect --pretty myapp_web
```

### Compatibilitat

Perquè el rollback sigui viable, l'aplicació s'ha de dissenyar tenint en compte aquesta possibilitat. Això és especialment crític quan hi ha canvis de model a la base de dades.

Migracions compatibles amb rollback:

* Afegir columnes noves amb valors per defecte.
* Crear taules noves.
* Afegir índexs.

Migracions problemàtiques:

* Eliminar columnes o taules (la versió anterior les necessita).
* Renombrar columnes (trenca ambdues versions).
* Canviar tipus de dades de forma incompatible.

Una estratègia habitual és separar els desplegaments en dues fases:

* Desplegament 1: Afegir els nous camps/taules sense eliminar els antics. El codi suporta ambdós esquemes.
* Desplegament 2: Un cop confirmada l'estabilitat, eliminar els camps/taules antics.

Aquesta tècnica es coneix com a *expand and contract* o *parallel change*.

### Configuració

De la mateixa manera que hem fet amb `update_config`, podem configurar el comportament del rollback amb `rollback_config`:

```yaml
services:
  web:
    image: myuser/myapp:${VERSION:-latest}
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
        failure_action: rollback
      rollback_config:
        parallelism: 1
        delay: 5s
        order: start-first
```

El `rollback_config` accepta els mateixos paràmetres que `update_config`.

| Paràmetre           | Descripció                                            | Valor per defecte |
|:--------------------|:------------------------------------------------------|:------------------|
| `parallelism`       | Nombre de tasques a revertir simultàniament           | 1                 |
| `delay`             | Temps d'espera entre reversions                       | 0s                |
| `order`             | Ordre d'operacions: `stop-first` o `start-first`      | `stop-first`      |
| `monitor`           | Temps per monitoritzar l'estat després de la reversió | 5s                |
| `max_failure_ratio` | Percentatge màxim de fallades tolerat                 | 0                 |

A l'exemple anterior, el *rollback* es fa més ràpidament (5 segons de delay en lloc de 10) per restaurar el servei el més aviat possible.

### Redesplegament

Una alternativa al rollback natiu passa per, simplement, tornar a desplegar una versió anterior de l'aplicació:

```bash
VERSION=1.1.0 docker stack deploy -c docker-stack.yml myapp
```

Aquesta aproximació és més explícita i queda registrada com un desplegament normal. És útil quan:

* Volem botar més d'una versió enrere.
* El rollback natiu no funciona per algun motiu.
* Preferim tenir un registre clar de totes les versions desplegades.

## Desplegament Blue-Green

El desplegament Blue-Green és una estratègia que manté dues versions de l'aplicació en execució simultàniament: la versió activa (e.g., la blava) i la nova versió (e.g., la verda). El tràfic es redirigeix de la blava a la verda quan la nova versió està llesta i verificada.

Avantatges:

* El canvi de versió és instantani.
* Si hi ha problemes, es redirigeix el tràfic de nou a la versió blava (*rollback* immediat).
* Es pot provar la versió verda abans de redirigir el tràfic.

Inconvenients:

* Cal tenir capacitat per executar dues versions simultàniament (duplicació de recursos).
* Augment de la complexitat, car requereix de la gestió del tràfic (Traefik, en el nostre cas).
* Les migracions de base de dades poden ser problemàtiques.

### Aproximacions

Hi ha dues aproximacions principals per implementar l'estratègia de desplegament Blue-Green amb Docker Swarm:

**Etiquetes sobre un únic stack**

En aquest context, usarem un sol stack amb dos serveis (`web-blue` i `web-green`). Per redirigir el tràfic de la versió blava a la verda es canvien les etiquetes dels serveis. El nostre servei Traefik dirigeix el tràfic en funció dels valors que anem configurant.

| Aspecte         | Descripció                                |
|:----------------|:------------------------------------------|
| Recursos        | Més eficient, comparteixen xarxa i volums |
| Canvi de tràfic | Instantani, via etiquetes                 |
| Gestió          | Un sol fitxer stack                       |

**Dos stacks separats**

En aquest cas, definirem dos stacks completament independents (`myapp-blue` i `myapp-green`). Per redirigir el tràfic de la versió blava a la verda es canvia la configuració del proxy extern o de la zona de DNS.

| Aspecte         | Descripció                          |
|:----------------|:------------------------------------|
| Recursos        | Duplicats completament              |
| Canvi de tràfic | Segons el mètode (DNS pot ser lent) |
| Gestió          | Dos fitxers stack                   |

La segona aproximació és més comuna quan s'usa un balancejador extern al clúster de Docker Swarm (e.g., HAProxy, un servei oferit pel propi proveïdor d'hospedatge, etc.) o quan es requereix aïllament complet entre versions, per exemple, amb bases de dades separades per a cada entorn.

En aquest article implementarem la primera aproximació, usant Traefik.

### Amb etiquetes

Per a aquesta aproximació ens cal definir dos serveis per a l'aplicació web, un per a cada color:

```yaml
# docker-stack.yml

services:
  traefik:
    image: traefik:v3.6
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    configs:
      - source: traefik_config
        target: /etc/traefik/traefik.yml
    networks:
      - public
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager

  web-blue:
    image: myuser/myapp:${VERSION_BLUE:-latest}
    environment:
      - DEBUG=false
      - ALLOWED_HOSTS=domini.com,www.domini.com
      # ... més variables
    secrets:
      - source: secret_key
        target: /run/secrets/SECRET_KEY
      # ... més secrets
    networks:
      - public
      - backend
    deploy:
      replicas: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.web.rule=Host(`domini.com`)"
        - "traefik.http.routers.web.entrypoints=https"
        - "traefik.http.services.web.loadbalancer.server.port=8080"

  web-green:
    image: myuser/myapp:${VERSION_GREEN:-latest}
    environment:
      - DEBUG=false
      - ALLOWED_HOSTS=domini.com,www.domini.com
      # ... més variables
    secrets:
      - source: secret_key
        target: /run/secrets/SECRET_KEY
      # ... més secrets
    networks:
      - public
      - backend
    deploy:
      replicas: 0  # Inicialment sense rèpliques
      labels:
        - "traefik.enable=false"  # Inicialment desactivat
        - "traefik.http.routers.web.rule=Host(`domini.com`)"
        - "traefik.http.routers.web.entrypoints=https"
        - "traefik.http.services.web.loadbalancer.server.port=8080"
  
  # ... resta de serveis (postgres, redis, worker, beat)

networks:
  public:
    driver: overlay
  backend:
    driver: overlay
    internal: true

configs:
  traefik_config:
    file: docker/traefik/traefik.prod.yml

secrets:
  secret_key:
    external: true
  postgres_user:
    external: true
  postgres_password:
    external: true
```

Per tant, inicialment tenim:

* El servei `web-blue` té 3 rèpliques i rep el tràfic.
* El servei `web-green` té 0 rèpliques i està desactivat a Traefik.

> L'etiqueta `traefik.enable=false` al servei `web-green` és redundant, car amb 0 rèpliques no hi ha cap contenidor executant-se, per tant Traefik no té res a descobrir. Aquesta etiqueta només seria necessària si el servei tengués rèpliques actives però volguéssim que Traefik l'ignorés.

En aquest context, el procés de desplegament d'una nova versió amb aquesta estratègia Blue-Green segueix aquests passos:

1. Desplegar `web-green` amb la nova versió.
   ```bash
   VERSION_BLUE=1.1.0 VERSION_GREEN=1.2.0 \
   docker stack deploy -c docker-stack.yml myapp
   ```

2. Augmentar les rèpliques de `web-green`.
   ```bash
   docker service scale myapp_web-green=3
   ```

3. Verificar l'estat dels servei de la versió `web-green`.
   ```bash
   docker service ps myapp_web-green
   ```

4. Verificar la nova funcionalitat. Abans de redirigir el tràfic, verificam que la nova versió funciona correctament accedint directament al servei intern o habilitant temporalment un subdomini o ruta de proves. Com a part d'aquestes proves revisarem els logs d'aplicació:
   ```bash
   docker service logs myapp_web-green
   ```

5. Un cop verificat, actualitzem les etiquetes per redirigir el tràfic:
   ```bash
   # Activar green a Traefik
   docker service update \
     --label-add "traefik.enable=true" \
     myapp_web-green
 
   # Desactivar blue a Traefik
   docker service update \
     --label-add "traefik.enable=false" \
     myapp_web-blue
   ```

6. Comprovam que el tràfic va a *Green* (e.g., usant `curl`) i verificam l'estat dels serveis:
   ```bash
   curl --head https://domini.com/version
   docker stack services myapp
   ```

7. Un cop confirmem que *Green* funciona correctament, podem reduir el número de rèpliques a *Blue*:
   ```bash
   docker service scale myapp_web-blue=0
   ```

> L'endpoint `/version` de l'aplicació web és molt útil en una aplicació web, com també ho són `/health` i `/ping`.

### Rollback

Si detectem problemes amb la versió *Green*, el rollback és immediat. En primer lloc, reactivam *Blue*:

```bash
docker service update \
  --label-add "traefik.enable=true" \
  myapp_web-blue
docker service scale myapp_web-blue=3
```

I, acte seguit, desactivam *Green*:
```bash
docker service update \
  --label-add "traefik.enable=false" \
  myapp_web-green
docker service scale myapp_web-green=0
```

El canvi és quasi instantani perquè blue encara existeix i té la configuració preparada.

### Scripting

El desplegament, com hem pogut veure abans, té dues parts ben diferenciades. La primera desplega la nova versió al servei inactiu i escala les rèpliques, mentre que la segona canvia el tràfic al servei inactiu i redueix l'antic.

Per automatitzar el procés, podem crear sengles scripts, de forma que puguem verificar manualment que tot està bé abans de fer el canvi de tràfic, obtenint així un procés més determinista.

**Primer script**

```bash
#!/bin/bash
#
# deploy/deploy-blue-green.sh
#
# Desplega una nova versió al servei inactiu (blue o green)
#
set -euo pipefail

MANAGER_HOST="root@aaa.bb.cc.10"
NEW_VERSION="${1:-}"

if [[ -z "$NEW_VERSION" ]]; then
    echo "Ús: $0 <versió>"
    echo "Exemple: $0 1.2.0"
    exit 1
fi

export DOCKER_HOST=ssh://$MANAGER_HOST

# Detectar quin color està actiu
BLUE_REPLICAS=$(
  docker service inspect myapp_web-blue \
  --format '{{.Spec.Mode.Replicated.Replicas}}' \
  2>/dev/null || echo "0" \
)

if [[ "$BLUE_REPLICAS" -gt 0 ]]; then
    INACTIVE="green"
else
    INACTIVE="blue"
fi

echo "Desplegant versió $NEW_VERSION a $INACTIVE..."

# Actualitzar la imatge i escalar
docker service update --image myuser/myapp:$NEW_VERSION myapp_web-$INACTIVE
docker service scale myapp_web-$INACTIVE=3

echo ""
echo "Verifica que el servei està llest:"
echo "watch docker service ps myapp_web-$INACTIVE"
```

**Segon script**

```bash
#!/bin/bash
#
# deploy/switch-blue-green.sh
#
# Canvia el tràfic entre blue i green
#
set -euo pipefail

MANAGER_HOST="root@aaa.bb.cc.10"
export DOCKER_HOST=ssh://$MANAGER_HOST

# Detectar quin color està actiu
BLUE_REPLICAS=$(
  docker service inspect myapp_web-blue \
  --format '{{.Spec.Mode.Replicated.Replicas}}' \
  2>/dev/null || echo "0"
)
GREEN_REPLICAS=$(
  docker service inspect myapp_web-green \
  --format '{{.Spec.Mode.Replicated.Replicas}}' \
  2>/dev/null || echo "0"
)

if [[ "$BLUE_REPLICAS" -gt 0 && "$GREEN_REPLICAS" -gt 0 ]]; then
    # Ambdós actius: activar el que té traefik.enable=false
    BLUE_ENABLED=$(
      docker service inspect myapp_web-blue \
      --format '{{index .Spec.Labels "traefik.enable"}}'
    )
    if [[ "$BLUE_ENABLED" == "true" ]]; then
        ACTIVE="blue"
        INACTIVE="green"
    else
        ACTIVE="green"
        INACTIVE="blue"
    fi
elif [[ "$BLUE_REPLICAS" -gt 0 ]]; then
    ACTIVE="blue"
    INACTIVE="green"
else
    ACTIVE="green"
    INACTIVE="blue"
fi

echo "Canviant tràfic de $ACTIVE a $INACTIVE..."

# Activar el servei inactiu
docker service update --label-add "traefik.enable=true" myapp_web-$INACTIVE

# Desactivar el servei actiu
docker service update --label-add "traefik.enable=false" myapp_web-$ACTIVE

# Reduir el servei antic
docker service scale myapp_web-$ACTIVE=0

echo "Tràfic redirigit a $INACTIVE"
```

Abans d'usar aquests scripts, cal fer-los executables:

```bash
chmod +x deploy/deploy-blue-green.sh
chmod +x deploy/switch-blue-green.sh
```

A l'hora de fer-ne ús, només necessitam la nova versió com a paràmetre del primer script:

1. Desplegar la nova versió al servei inactiu i escalar les rèpliques:
   ```bash
   deploy/deploy-blue-green.sh 1.2.0
   ```

2. Verificar que el servei està llest:
   ```bash
   watch docker service ps myapp_web-<versió-inactiva>
   ```

3. Canviar el tràfic al servei inactiu i reduir l'antic:
   ```bash
   deploy/switch-blue-green.sh
   ```

## Comparativa d'estratègies

| Aspecte               | Rolling update     | Blue-Green                 |
|:----------------------|:-------------------|:---------------------------|
| Temps de desplegament | Gradual (minuts)   | Instantani (segons)        |
| Recursos addicionals  | Mínims             | Duplicats durant transició |
| Complexitat           | Baixa              | Mitjana                    |
| Rollback              | Automàtic o manual | Instantani                 |
| Verificació prèvia    | No                 | Sí                         |
| Risc                  | Progressiu         | Tot o res                  |

Quan usar cada estratègia:

* **Rolling Update**: Per a la majoria de desplegaments rutinaris. És l'opció per defecte i funciona bé per a actualitzacions incrementals.
* **Blue-Green**: Per a desplegaments crítics on el zero downtime és essencial, o quan es vol verificar la nova versió abans de redirigir el tràfic.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l’aprenentatge progressiu.

### Exercici 1

**Rolling update avançat**

Configura un rolling update amb paràmetres avançats i observa el comportament del rollback automàtic.

Tasques:

1. Modifica el fitxer `docker-stack.yml` per afegir una configuració avançada de rolling update al servei `web`:
   ```yaml
   deploy:
     replicas: 4
     update_config:
       parallelism: 2
       delay: 15s
       order: start-first
       failure_action: rollback
       monitor: 30s
       max_failure_ratio: 0.3
     rollback_config:
       parallelism: 2
       delay: 5s
       order: start-first
   ```
  
2. Desplega una nova versió i observa el progrés del rolling update:
   ```
   bash
   VERSION=1.2.0 docker stack deploy -c docker-stack.yml myapp
   watch docker service ps myapp_web
   ```

3. Simula una fallada desplegant una imatge que no existeix:
   ```bash
   VERSION=inexistent docker stack deploy -c docker-stack.yml myapp
   ```

4. Observa com Docker Swarm detecta la fallada i fa rollback automàticament.

5. Verifica que el servei ha tornat a la versió anterior:
   ```bash
   docker service inspect --pretty myapp_web
   ```

### Exercici 2

**Rollback manual**

Practica el rollback manual usant tant la comanda nativa com el redesplegament d'una versió anterior.

Tasques:

1. Desplega dues versions consecutives de l'aplicació:
   ```bash
   VERSION=1.1.0 docker stack deploy -c docker-stack.yml myapp
   # Espera que estigui llest
   VERSION=1.2.0 docker stack deploy -c docker-stack.yml myapp
   ```

2. Executa un rollback manual amb la comanda nativa:
   ```bash
   docker service rollback myapp_web
   ```

3. Verifica que el servei ha tornat a la versió 1.1.0:
   ```bash
   docker service inspect myapp_web \
   --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
   ```

4. Torna a desplegar la versió 1.2.0:
   ```bash
   VERSION=1.2.0 docker stack deploy -c docker-stack.yml myapp
   ```

5. Ara, fes rollback usant el mètode de redesplegament:
   ```bash
   VERSION=1.1.0 docker stack deploy -c docker-stack.yml myapp
   ```

6. Compara ambdós mètodes: quines diferències observes en el comportament i en la informació que mostra `docker service inspect`?

### Exercici 3

**Desplegament Blue-Green**

Implementa un desplegament Blue-Green complet, incloent el canvi de tràfic i el rollback.

Tasques:

1. Modifica el fitxer `docker-stack.yml` per tenir els serveis `web-blue` i `web-green` segons l'estructura presentada a l'article.

2. Desplega l'stack inicial amb `web-blue` actiu:
   ```bash
   VERSION_BLUE=1.1.0 VERSION_GREEN=1.1.0 \
   docker stack deploy -c docker-stack.yml myapp
   docker service scale myapp_web-blue=3
   ```

3. Verifica que només `web-blue` rep tràfic:
   ```
   docker stack services myapp
   curl --head https://domini.com
   ```
  
4. Desplega la nova versió a `web-green`:
   ```bash
   docker service update --image myuser/myapp:1.2.0 myapp_web-green
   docker service scale myapp_web-green=3
   ```

5. Verifica que `web-green` està llest:
   ```bash
   watch docker service ps myapp_web-green
   docker service logs myapp_web-green
   ```

6. Redirigeix el tràfic a `web-green`:
   ```bash
   docker service update \
   --label-add "traefik.enable=true" myapp_web-green
   docker service update \
   --label-add "traefik.enable=false" myapp_web-blue
   ```

7. Verifica el canvi i redueix `web-blue`:
   ```bash
   curl --head https://domini.com
   docker service scale myapp_web-blue=0
   ```

8. Practica el rollback tornant a `web-blue`:
   ```bash
   docker service scale myapp_web-blue=3
   docker service update \
   --label-add "traefik.enable=true" myapp_web-blue
   docker service update \
   --label-add "traefik.enable=false" myapp_web-green
   docker service scale myapp_web-green=0
   ```

9. Finalment, copia els scripts `deploy-blue-green.sh` i `switch-blue-green.sh` al directori `deploy/` del teu projecte, fes-los executables i repeteix el procés usant els scripts.
