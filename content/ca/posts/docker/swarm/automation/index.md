---
title: "Automatització del desplegament"
date: 2026-02-11
lastmod: 2026-02-11
description: "Scripts de desplegament, gestió automatitzada de configs i secrets, i pipelines de desplegament"
summary: "Scripts de desplegament, gestió automatitzada de configs i secrets, i pipelines de desplegament"
categories: ["teaching"]
tags: ["docker", "swarm"]
series: ["Docker Swarm"]
series_order: 10
weight: 100
slug: automatitzacio
draft: true
---

Fins ara hem executat les comandes de Docker Swarm manualment: crear secrets, configurar serveis, desplegar stacks. I també hem vist com fer-ho de forma declarativa en un fitxer `docker-compose.yml`. Anem ara a automatitzar una mica més aquest procés per a garantir desplegaments consistents, repetibles i lliures d'errors humans.

## Estructura de projecte recomanada

Abans d'automatitzar, convé organitzar el projecte de manera que faciliti el desplegament:

```
myapp/
├── src/                          # Codi font de l'aplicació
│   └── ...
├── docker/
│   ├── Dockerfile                # Imatge de l'aplicació
│   └── Dockerfile.worker         # Imatge del worker (si és diferent)
├── config/
│   ├── traefik.yml               # Configuració de Traefik
│   └── ...                       # Altres fitxers de configuració
├── deploy/
│   ├── docker-stack.yml          # Definició de l'stack per a Swarm
│   ├── docker-stack.prod.yml     # Overrides per a producció (opcional)
│   ├── deploy.sh                 # Script principal de desplegament
│   └── manage-secrets.sh         # Script per gestionar configs/secrets
├── .env.example                  # Plantilla de variables d'entorn
├── .env                          # Variables locals (NO cometre al repo)
├── .env.production               # Variables de producció (NO cometre al repo)
└── .gitignore
```

**Fitxer `.gitignore`**

```gitignore
# Variables d'entorn amb valors reals
.env
.env.production
.env.staging

# Mantenim només l'exemple
!.env.example
```

## Gestió automatitzada de configs i secrets

Al tema anterior vam veure com crear configs i secrets manualment. Quan tenim desenes de variables, això és impracticable. L'script següent automatitza el procés llegint un fitxer `.env.production`.

### Fitxer `.env.example`

```bash
# ===========================================
# Configuració (no sensible)
# ===========================================
DEBUG=false
ALLOWED_HOSTS=example.com,www.example.com
POSTGRES_HOST=postgres
POSTGRES_DB=myapp
POSTGRES_PORT=5432
REDIS_URL=redis://redis:6379/0

# ===========================================
# Secrets (credencials i dades sensibles)
# ===========================================
SECRET_KEY=genera-una-clau-segura
POSTGRES_USER=myapp
POSTGRES_PASSWORD=genera-una-contrasenya-segura
```

### Script `manage-secrets.sh`

```bash
#!/bin/bash
#
# Gestiona configs i secrets de Docker Swarm a partir d'un fitxer .env
#
# Ús:
#   ./manage-secrets.sh [create|remove] [fitxer_env] [nom_stack]
#
# Exemples:
#   ./manage-secrets.sh create .env.production myapp
#   ./manage-secrets.sh remove .env.production myapp
#

set -euo pipefail

# === CONFIGURACIÓ ===
# Definim quines variables són configs i quines són secrets
CONFIGS=(
    "DEBUG"
    "ALLOWED_HOSTS"
    "POSTGRES_HOST"
    "POSTGRES_DB"
    "POSTGRES_PORT"
    "REDIS_URL"
)

SECRETS=(
    "SECRET_KEY"
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
)

# === FUNCIONS ===

show_usage() {
    echo "Ús: $0 [create|remove] [fitxer_env] [nom_stack]"
    echo ""
    echo "Comandes:"
    echo "  create    Crea configs i secrets al clúster"
    echo "  remove    Elimina configs i secrets del clúster"
    echo ""
    echo "Exemples:"
    echo "  $0 create .env.production myapp"
    echo "  $0 remove .env.production myapp"
    exit 1
}

create_configs_and_secrets() {
    local env_file="$1"
    local stack_name="$2"

    # Comprova que el fitxer existeix
    if [[ ! -f "$env_file" ]]; then
        echo "Error: No s'ha trobat el fitxer $env_file"
        exit 1
    fi

    # Carrega les variables del fitxer
    set -a
    source "$env_file"
    set +a

    echo "=== Creant configs ==="
    for name in "${CONFIGS[@]}"; do
        value="${!name:-}"
        if [[ -z "$value" ]]; then
            echo "  Avís: $name no té valor, s'omet"
            continue
        fi

        # Nom del config: stack_variable (en minúscules)
        config_name="${stack_name}_${name,,}"

        # Si ja existeix, l'eliminem primer
        # ATENCIÓ: Això fallarà si el config està en ús per un servei.
        # En aquest cas, cal primer actualitzar o eliminar el servei.
        if docker config inspect "$config_name" &>/dev/null; then
            echo "  Actualitzant config: $config_name"
            docker config rm "$config_name" 2>/dev/null || {
                echo "  Error: No s'ha pogut eliminar $config_name (pot estar en ús)"
                echo "  Executa primer: docker stack rm $stack_name"
                exit 1
            }
        else
            echo "  Creant config: $config_name"
        fi

        echo "$value" | docker config create "$config_name" -
    done

    echo ""
    echo "=== Creant secrets ==="
    for name in "${SECRETS[@]}"; do
        value="${!name:-}"
        if [[ -z "$value" ]]; then
            echo "  Avís: $name no té valor, s'omet"
            continue
        fi

        # Nom del secret: stack_variable (en minúscules)
        secret_name="${stack_name}_${name,,}"

        # Si ja existeix, l'eliminem primer
        # ATENCIÓ: Mateix problema que amb configs
        if docker secret inspect "$secret_name" &>/dev/null; then
            echo "  Actualitzant secret: $secret_name"
            docker secret rm "$secret_name" 2>/dev/null || {
                echo "  Error: No s'ha pogut eliminar $secret_name (pot estar en ús)"
                echo "  Executa primer: docker stack rm $stack_name"
                exit 1
            }
        else
            echo "  Creant secret: $secret_name"
        fi

        echo "$value" | docker secret create "$secret_name" -
    done

    echo ""
    echo "=== Resum ==="
    echo "Configs creats: ${#CONFIGS[@]}"
    echo "Secrets creats: ${#SECRETS[@]}"
}

remove_configs_and_secrets() {
    local env_file="$1"
    local stack_name="$2"

    echo "=== Eliminant configs ==="
    for name in "${CONFIGS[@]}"; do
        config_name="${stack_name}_${name,,}"
        if docker config inspect "$config_name" &>/dev/null; then
            echo "  Eliminant config: $config_name"
            docker config rm "$config_name" || echo "  Avís: No s'ha pogut eliminar (pot estar en ús)"
        fi
    done

    echo ""
    echo "=== Eliminant secrets ==="
    for name in "${SECRETS[@]}"; do
        secret_name="${stack_name}_${name,,}"
        if docker secret inspect "$secret_name" &>/dev/null; then
            echo "  Eliminant secret: $secret_name"
            docker secret rm "$secret_name" || echo "  Avís: No s'ha pogut eliminar (pot estar en ús)"
        fi
    done

    echo ""
    echo "=== Neteja completada ==="
}

# === MAIN ===

ACTION="${1:-}"
ENV_FILE="${2:-.env.production}"
STACK_NAME="${3:-myapp}"

case "$ACTION" in
    create)
        create_configs_and_secrets "$ENV_FILE" "$STACK_NAME"
        ;;
    remove)
        remove_configs_and_secrets "$ENV_FILE" "$STACK_NAME"
        ;;
    *)
        show_usage
        ;;
esac
```

### Ús de l'script

```bash
# Preparar el fitxer de producció
cp .env.example .env.production
nano .env.production  # Editar amb els valors reals

# Crear configs i secrets
./deploy/manage-secrets.sh create .env.production myapp

# Verificar
docker config ls
docker secret ls

# Eliminar (quan calgui)
./deploy/manage-secrets.sh remove .env.production myapp
```

### Integració amb el fitxer stack

Els configs i secrets creats per l'script s'han de referenciar com a externs al fitxer stack:

```yaml
# docker-stack.yml

services:
  web:
    image: registry.example.com/myapp:${VERSION:-latest}
    environment:
      # Variables no sensibles es poden passar directament
      - POSTGRES_HOST=postgres
      - POSTGRES_DB=myapp
    configs:
      - source: myapp_allowed_hosts
        target: /run/configs/ALLOWED_HOSTS
    secrets:
      - source: myapp_secret_key
        target: /run/secrets/SECRET_KEY
      - source: myapp_postgres_password
        target: /run/secrets/POSTGRES_PASSWORD
    # ...

configs:
  myapp_debug:
    external: true
  myapp_allowed_hosts:
    external: true
  myapp_postgres_host:
    external: true
  myapp_postgres_db:
    external: true
  myapp_postgres_port:
    external: true
  myapp_redis_url:
    external: true

secrets:
  myapp_secret_key:
    external: true
  myapp_postgres_user:
    external: true
  myapp_postgres_password:
    external: true
```

## Versionat d'imatges

Un aspecte crític del desplegament és identificar quina versió de l'aplicació s'està executant.

### Estratègies de tags

| Estratègia | Exemple | Avantatges | Inconvenients |
|:-----------|:--------|:-----------|:--------------|
| `latest` | `myapp:latest` | Simple | No saps quina versió s'executa |
| Versió semàntica | `myapp:1.2.3` | Clara, immutable | Cal mantenir versions manualment |
| Hash de commit | `myapp:a1b2c3d` | Traçabilitat exacta | Poc llegible |
| Data | `myapp:20260211` | Ordenació temporal | Pot haver-hi múltiples deploys/dia |
| Combinada | `myapp:1.2.3-a1b2c3d` | Llegible i traçable | Més llarga |

**Recomanació:** Usar versió semàntica per a releases formals i hash de commit per a desplegaments continus.

### Generar el tag automàticament

```bash
# Obtenir el hash curt del commit actual
GIT_HASH=$(git rev-parse --short HEAD)

# Obtenir el tag de versió si existeix
GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")

# Decidir quin tag usar
if [[ -n "$GIT_TAG" ]]; then
    VERSION="$GIT_TAG"
else
    VERSION="$GIT_HASH"
fi

# Construir i pujar la imatge
docker build -t registry.example.com/myapp:$VERSION .
docker push registry.example.com/myapp:$VERSION
```

## Pipeline de desplegament

Un pipeline de desplegament és la seqüència de passos que s'executen per portar el codi des del repositori fins a producció.

### Flux de treball local (amb VirtualBox/Proxmox)

Quan treballem amb un clúster local per a proves o aprenentatge, el flux típic és:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MÀQUINA DE DESENVOLUPAMENT                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Desenvolupar i provar localment                                 │
│     └── docker compose up                                           │
│                                                                     │
│  2. Cometre canvis                                                  │
│     └── git add . && git commit && git push                         │
│                                                                     │
│  3. Construir imatge                                                │
│     └── docker build -t registry:5000/myapp:$VERSION .              │
│                                                                     │
│  4. Pujar imatge al registre                                        │
│     └── docker push registry:5000/myapp:$VERSION                    │
│                                                                     │
│  5. Connectar al manager del clúster                                │
│     └── ssh manager1                                                │
│         (o usar DOCKER_HOST=ssh://manager1)                         │
│                                                                     │
│  6. Crear/actualitzar configs i secrets                             │
│     └── ./manage-secrets.sh create .env.production myapp            │
│                                                                     │
│  7. Desplegar l'stack                                               │
│     └── docker stack deploy -c docker-stack.yml myapp               │
│                                                                     │
│  8. Verificar el desplegament                                       │
│     └── docker stack services myapp                                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

Aquest flux és manual però controlat: el desenvolupador executa cada pas i pot verificar el resultat abans de continuar.

### Flux de treball amb CI/CD

En un entorn professional, el flux s'automatitza amb eines de CI/CD (GitHub Actions, GitLab CI, Jenkins, Gitea Actions, etc.). El principi és el mateix, però els passos s'executen automàticament en resposta a events del repositori:

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  REPOSITORI  │      │  SERVIDOR    │      │   CLÚSTER    │
│    (Git)     │      │    CI/CD     │      │    SWARM     │
└──────┬───────┘      └──────┬───────┘      └──────┬───────┘
       │                     │                     │
       │  1. Push/Merge      │                     │
       │────────────────────>│                     │
       │                     │                     │
       │              2. Clonar repo               │
       │              3. Executar tests            │
       │              4. Construir imatge          │
       │              5. Pujar al registre         │
       │                     │                     │
       │                     │  6. SSH al manager  │
       │                     │────────────────────>│
       │                     │                     │
       │                     │  7. Gestionar       │
       │                     │     secrets         │
       │                     │────────────────────>│
       │                     │                     │
       │                     │  8. docker stack    │
       │                     │     deploy          │
       │                     │────────────────────>│
       │                     │                     │
       │                     │  9. Verificar       │
       │                     │<────────────────────│
       │                     │                     │
       │  10. Notificar      │                     │
       │<────────────────────│                     │
       │                     │                     │
```

**Diferències clau:**

| Aspecte | Flux local | Flux CI/CD |
|:--------|:-----------|:-----------|
| Execució | Manual | Automàtica (trigger per push/merge) |
| Entorn | Màquina del desenvolupador | Servidor dedicat |
| Credencials | Fitxer `.env.production` local | Variables secretes del CI/CD |
| Accés al clúster | SSH directe o DOCKER_HOST | SSH amb clau desplegada al CI/CD |
| Tests | Opcionals | Obligatoris abans de desplegar |
| Rollback | Manual | Pot ser automàtic si fallen els tests |

### Script de desplegament complet

Aquest script unifica tots els passos del flux local:

```bash
#!/bin/bash
#
# Script de desplegament per a Docker Swarm
#
# Ús:
#   ./deploy.sh [versió]
#
# Exemples:
#   ./deploy.sh              # Usa el hash del commit actual
#   ./deploy.sh 1.2.3        # Usa la versió especificada
#

set -euo pipefail

# === CONFIGURACIÓ ===
REGISTRY="registry.example.com"
IMAGE_NAME="myapp"
STACK_NAME="myapp"
STACK_FILE="deploy/docker-stack.yml"
ENV_FILE=".env.production"
MANAGER_HOST="manager1"

# === FUNCIONS ===

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

get_version() {
    if [[ -n "${1:-}" ]]; then
        echo "$1"
    else
        # Usar tag git si existeix, sinó hash del commit
        git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD
    fi
}

check_prerequisites() {
    log "Comprovant prerequisits..."
    
    # Comprovar que estem en un repo git
    git rev-parse --git-dir > /dev/null 2>&1 || error "No és un repositori git"
    
    # Comprovar que no hi ha canvis sense cometre
    if [[ -n $(git status --porcelain) ]]; then
        error "Hi ha canvis sense cometre. Fes commit primer."
    fi
    
    # Comprovar que existeix el fitxer d'entorn
    [[ -f "$ENV_FILE" ]] || error "No s'ha trobat $ENV_FILE"
    
    # Comprovar que existeix el fitxer stack
    [[ -f "$STACK_FILE" ]] || error "No s'ha trobat $STACK_FILE"
    
    log "Prerequisits correctes"
}

build_and_push() {
    local version="$1"
    local full_image="$REGISTRY/$IMAGE_NAME:$version"
    
    log "Construint imatge: $full_image"
    docker build -t "$full_image" -f docker/Dockerfile .
    
    log "Pujant imatge al registre..."
    docker push "$full_image"
    
    log "Imatge pujada correctament"
}

deploy_to_swarm() {
    local version="$1"
    
    log "Connectant al clúster..."
    
    # Opció 1: Usar DOCKER_HOST per executar comandes remotament
    export DOCKER_HOST="ssh://$MANAGER_HOST"
    
    # Opció 2: Alternativa amb SSH directe (comentada)
    # ssh "$MANAGER_HOST" "cd /path/to/deploy && ..."
    
    log "Actualitzant configs i secrets..."
    ./deploy/manage-secrets.sh create "$ENV_FILE" "$STACK_NAME"
    
    log "Desplegant stack amb versió $version..."
    VERSION="$version" docker stack deploy -c "$STACK_FILE" "$STACK_NAME"
    
    log "Esperant que els serveis estiguin llestos..."
    sleep 5
    
    # Mostrar estat dels serveis
    docker stack services "$STACK_NAME"
    
    # Restaurar DOCKER_HOST
    unset DOCKER_HOST
}

verify_deployment() {
    log "Verificant desplegament..."
    
    export DOCKER_HOST="ssh://$MANAGER_HOST"
    
    # Comprovar que tots els serveis tenen les rèpliques desitjades
    local services
    services=$(docker stack services "$STACK_NAME" --format "{{.Name}} {{.Replicas}}")
    
    local all_ok=true
    while IFS= read -r line; do
        local name replicas
        name=$(echo "$line" | awk '{print $1}')
        replicas=$(echo "$line" | awk '{print $2}')
        
        # El format és "actual/desired", per exemple "3/3"
        local actual desired
        actual=$(echo "$replicas" | cut -d'/' -f1)
        desired=$(echo "$replicas" | cut -d'/' -f2)
        
        if [[ "$actual" != "$desired" ]]; then
            log "AVÍS: $name té $actual/$desired rèpliques"
            all_ok=false
        fi
    done <<< "$services"
    
    unset DOCKER_HOST
    
    if [[ "$all_ok" == "true" ]]; then
        log "Tots els serveis estan correctes"
    else
        log "Alguns serveis no estan al 100%. Revisa amb: docker stack ps $STACK_NAME"
    fi
}

# === MAIN ===

main() {
    local version
    version=$(get_version "${1:-}")
    
    log "=== Iniciant desplegament de $IMAGE_NAME:$version ==="
    
    check_prerequisites
    build_and_push "$version"
    deploy_to_swarm "$version"
    verify_deployment
    
    log "=== Desplegament completat ==="
    log "Versió desplegada: $version"
}

main "$@"
```

### Ús del script

```bash
# Desplegament amb versió automàtica (hash del commit)
./deploy/deploy.sh

# Desplegament amb versió específica
./deploy/deploy.sh 1.2.3

# Sortida esperada:
# [2026-02-11 10:30:00] === Iniciant desplegament de myapp:a1b2c3d ===
# [2026-02-11 10:30:00] Comprovant prerequisits...
# [2026-02-11 10:30:00] Prerequisits correctes
# [2026-02-11 10:30:01] Construint imatge: registry.example.com/myapp:a1b2c3d
# [2026-02-11 10:30:45] Pujant imatge al registre...
# [2026-02-11 10:31:20] Imatge pujada correctament
# [2026-02-11 10:31:21] Connectant al clúster...
# [2026-02-11 10:31:22] Actualitzant configs i secrets...
# [2026-02-11 10:31:25] Desplegant stack amb versió a1b2c3d...
# [2026-02-11 10:31:30] Esperant que els serveis estiguin llestos...
# [2026-02-11 10:31:35] Verificant desplegament...
# [2026-02-11 10:31:36] Tots els serveis estan correctes
# [2026-02-11 10:31:36] === Desplegament completat ===
# [2026-02-11 10:31:36] Versió desplegada: a1b2c3d
```

## Consideracions de seguretat

### Fitxers sensibles

Mai cometre fitxers amb credencials al repositori:

```gitignore
# .gitignore
.env
.env.*
!.env.example
*.pem
*.key
secrets/
```

### Accés al clúster

Per al flux local, l'accés via SSH és suficient. Per a CI/CD:

1. Crear una clau SSH específica per al CI/CD.
2. Afegir la clau pública als nodes manager.
3. Emmagatzemar la clau privada com a secret del CI/CD.
4. Limitar els permisos de l'usuari del CI/CD al mínim necessari.

### Variables del CI/CD

Els sistemes de CI/CD permeten definir variables secretes que no es mostren als logs:

| Variable | Contingut |
|:---------|:----------|
| `SSH_PRIVATE_KEY` | Clau privada per connectar al clúster |
| `REGISTRY_USER` | Usuari del registre d'imatges |
| `REGISTRY_PASSWORD` | Contrasenya del registre |
| `SWARM_MANAGER_HOST` | Adreça del node manager |

Aquestes variables es passen a l'script de desplegament sense exposar-les al codi font.

## Resum

| Component | Funció |
|:----------|:-------|
| `.env.example` | Plantilla de variables (es comete al repo) |
| `.env.production` | Variables reals (NO es comete) |
| `manage-secrets.sh` | Crea configs i secrets al clúster |
| `deploy.sh` | Script complet de desplegament |
| `docker-stack.yml` | Definició de l'stack amb `external: true` |

**Flux de desplegament:**

1. Editar codi i fer commit
2. Executar `./deploy.sh [versió]`
3. L'script construeix, puja i desplega automàticament
4. Verificar el resultat

## Exercici pràctic

L'objectiu d'aquest exercici és crear un pipeline de desplegament automatitzat per a una aplicació web senzilla.

Requisits:

* Un clúster Docker Swarm amb almenys 2 nodes.
* Un registre d'imatges accessible des del clúster (pot ser local).
* Git instal·lat a la màquina de desenvolupament.

Tasques:

1. **Preparar l'estructura del projecte**:
   * Crea un directori `myapp` amb l'estructura recomanada.
   * Crea un `Dockerfile` senzill que serveixi una pàgina HTML amb nginx.
   * Inicialitza un repositori git.

2. **Crear els scripts de desplegament**:
   * Copia l'script `manage-secrets.sh` i adapta les llistes CONFIGS i SECRETS.
   * Copia l'script `deploy.sh` i ajusta les variables (REGISTRY, MANAGER_HOST, etc.).
   * Fes els scripts executables amb `chmod +x`.

3. **Preparar la configuració**:
   * Crea el fitxer `.env.example` amb les variables necessàries.
   * Crea el fitxer `.env.production` amb valors reals.
   * Crea el fitxer `docker-stack.yml` amb els configs i secrets com a externs.

4. **Primer desplegament**:
   * Executa `./deploy/manage-secrets.sh create .env.production myapp`.
   * Verifica que els configs i secrets s'han creat.
   * Executa `./deploy/deploy.sh`.
   * Comprova que l'aplicació funciona.

5. **Actualització**:
   * Modifica la pàgina HTML.
   * Fes commit dels canvis.
   * Executa `./deploy/deploy.sh` de nou.
   * Verifica que el canvi s'ha aplicat.

6. **Simular un desplegament amb versió específica**:
   * Crea un tag git: `git tag 1.0.0`.
   * Executa `./deploy/deploy.sh 1.0.0`.
   * Verifica que la imatge té el tag correcte al registre.

7. **Neteja**:
   * Elimina l'stack: `docker stack rm myapp`.
   * Elimina configs i secrets: `./deploy/manage-secrets.sh remove .env.production myapp`.
   * Verifica que tot s'ha eliminat.
