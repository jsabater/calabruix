---
title: "Automatització del desplegament"
date: 2026-02-28
lastmod: 2026-02-28
description: "Scripts de desplegament, gestió automatitzada de secrets i pipelines de desplegament"
summary: "Scripts de desplegament, gestió automatitzada de secrets i pipelines de desplegament"
categories: ["teaching"]
tags: ["docker", "swarm", "automation", "ci/cd"]
series: ["Docker Swarm"]
series_order: 10
weight: 100
slug: automatitzacio
---

Fins ara hem executat les comandes de Docker Swarm manualment: crear secrets, configurar serveis, desplegar stacks. En aquest article automatitzarem el procés per garantir desplegaments consistents, repetibles i lliures d'errors humans.

## Estructura de projecte

Abans d'automatitzar, convé organitzar el projecte de manera que faciliti el desplegament. Aquesta és l'estructura que hem anat construint al llarg dels temes anteriors, a la qual hem afegit el directory `deploy/`:

```text
myapp/
├── src/                       # Codi font de l'aplicació
│   └── ...
├── docker/
│   ├── app/
│   │   └── Dockerfile         # Imatge de l'aplicació
│   └── traefik/
│       ├── traefik.devel.yml  # Configuració per a desenvolupament
│       └── traefik.prod.yml   # Configuració per a producció
├── deploy/
│   ├── deploy.sh              # Script principal de desplegament
│   └── create-secrets.sh      # Script per crear els secrets
├── docker-compose.yml         # Desenvolupament local
├── docker-stack.yml           # Stack de producció
├── .env.example               # Plantilla de variables d'entorn
├── .env                       # Variables locals
├── .env.prod                  # Variables de producció
└── .gitignore
```

El fitxer `.gitignore` ha d'excloure tots els fitxers amb credencials:

```gitignore
# Variables d'entorn amb valors reals
.env
.env.prod
.env.staging

# Mantenim només l'exemple
!.env.example

# Claus i certificats
*.pem
*.key
```

## Gestió de secrets

En articles anteriors vàrem veure com crear secrets manualment. Puntualment, pot ser sigui necessària una gestió manual però, en termes generals, ens convé automatitzar aquesta tasca per evitar errades humanes.

La millor manera de gestionar aquests automatismes és a través d'eines com [Ansible](https://docs.ansible.com/) o [Pyinfra](https://pyinfra.com/):

```yaml
# Exemple de tasca d'un playbook d'Ansible que crea un secret
- name: Crear secret a Docker Swarm
  community.docker.docker_secret:
    name: postgres_password
    data: "{{ postgres_password }}"  # Variable de la bòveda
    state: present
```

Però, per simplificar, en aquest article usarem un script de BASH que faci ús dels valors del fitxer `.env.prod`. Aquest fitxer conté els valors reals per a producció i, per tant, mai s'ha de cometre al repositori:

```bash
# Credencials i dades sensibles
SECRET_KEY=una-clau-molt-segura-generada-aleatoriament
POSTGRES_USER=myapp
POSTGRES_PASSWORD=una-contrasenya-molt-segura
...
```

> Els noms d'usuari són també secrets i com a tal cal considerar-los.

En aquest context, el flux de feina que seguiríem seria el següent:

1. Inicialitzar el clúster al `node1`.
2. Unir la resta de nodes al clúster (`node2` i `node3`).
3. Configurar la variable `DOCKER_HOST`.
4. Executar l'script `deploy/create-secrets.sh`.

```bash
#!/bin/bash
#
# deploy/create-secrets.sh
#
# Crea els secrets inicials de Docker Swarm a partir d'un fitxer
# Ús: deploy/create-secrets.sh [fitxer_env]
#
set -euo pipefail

ENV_FILE="${1:-.env.prod}"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: No s'ha trobat $ENV_FILE"
    exit 1
fi

# Carrega les variables
set -a
source "$ENV_FILE"
set +a

# Llista de secrets a crear
SECRETS=("SECRET_KEY" "POSTGRES_USER" "POSTGRES_PASSWORD")

for name in "${SECRETS[@]}"; do
    value="${!name:-}"
    secret_name="${name,,}"  # Converteix a minúscules
    
    if [[ -z "$value" ]]; then
        echo "Avís: $name buit, s'omet"
    elif docker secret inspect "$secret_name" &>/dev/null; then
        echo "Existeix: $secret_name"
    else
        echo "$value" | docker secret create "$secret_name" -
        echo "Creat: $secret_name"
    fi
done
```

Abans de fer ús de l'script, revisa els següents punts:

1. L'script té permisos d'execució:
   ```bash
   chmod +x deploy/create-secrets.sh
   ```

2. El fitxer `.env.prod`, generat a partir del fitxer `.env.example`, conté totes les variables necessàries i aquestes tenen els valors desitjats (recuperats d'una bòveda).
   ```bash
   cp .env.example .env.prod
   vi .env.prod
   ```

3. La variable `SECRETS` dins l'script conté la llista correcta de secrets a crear.
   ```bash
   grep ^SECRETS deploy/create-secrets.sh
   ```

4. Has configurat la variable `DOCKER_HOST` amb la connexió al node gestor:
   ```bash
   export DOCKER_HOST=ssh://root@aaa.bb.cc.10
   ```

Ara ja pots executar l'script:

```bash
cd ~/Projects/myapp
deploy/create-secrets.sh .env.prod
```

Una vegada finalitzada la seva execució, verifica el resultat:

```bash
docker secret ls
```

L'script no sobreescriu secrets existents. Recorda que, si necessites actualitzar un secret, cal rotar-lo, com vam veure al tema anterior.

## Versionat d'imatges

Un aspecte crític del desplegament és identificar quina versió de l'aplicació s'està executant. Per a assolir aquest objecti podem usar diverses estratègies que fan ús d'etiquetes.

| Estratègia       | Exemple               | Avantatges          | Inconvenients                      |
|:-----------------|:----------------------|:--------------------|:-----------------------------------|
| `latest`         | `myapp:latest`        | Simple              | No sabem quina versió s'executa    |
| Versió semàntica | `myapp:1.2.3`         | Clara, immutable    | Cal mantenir versions manualment   |
| Hash de commit   | `myapp:a1b2c3d`       | Traçabilitat exacta | Poc llegible                       |
| Data             | `myapp:20260211`      | Ordenació temporal  | Pot haver-hi múltiples deploys/dia |
| Combinada        | `myapp:1.2.3-a1b2c3d` | Llegible i traçable | Més llarga                         |

La recomanació és usar versió semàntica per a releases formals i hash de commit per a desplegaments continus durant el desenvolupament.

> Usar `latest` és còmode per a desenvolupament local. Per a qualsevol entorn de producció, usar una etiqueta immutable (hash o versió semàntica) és essencial per a la traçabilitat i la capacitat de fer rollback.

Per aplicar aquesta recomanació, dins el context d'un conducte de CI/CD amb desplegaments automàtics de noves versions, podríem automatitzar el versionat de la següent forma:

```bash
# Obtenir el tag de versió, si existeix, o el hash curt del commit
get_version() {
    git describe --tags --exact-match 2>/dev/null || \
    git rev-parse --short HEAD
}

VERSION=$(get_version)

# Construir i pujar la imatge
docker build -t myuser/myapp:$VERSION -f docker/app/Dockerfile .
docker push myuser/myapp:$VERSION
```

## Conducte CI/CD

Un conducte de desplegament i integració continuus, o pipeline de CI/CD, és la seqüència de passos que s'executen per dur el codi des del repositori fins a producció. En un entorn professional, és dessitjable automatitzar aquest flux amb eines específiques, com [Woodpecker CI](https://woodpecker-ci.org/), [Forgejo Actions](https://forgejo.org/docs/next/admin/actions/), [GitLab CI/CD](https://docs.gitlab.com/ci/) o [GitHub Actions](https://github.com/features/actions).

En aquest cas, els passos s'executen automàticament en resposta a events del repositori:

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart LR
    subgraph repo["Repositori"]
        A[Push/Merge]
    end

    subgraph ci["Servidor CI/CD"]
        direction LR
        B[Clonar] --> C[Tests] --> D[Anàlisi<br>seguretat]
    end

    subgraph cd["Servidor CI/CD"]
        direction LR
        E[Build<br>imatges] --> F[Push a<br>registre]
    end

    subgraph cluster["Clúster Swarm"]
        direction LR
        G[Desplegar] --> H[Verificar]
    end

    A ~~~ B
    D ~~~ E
    F ~~~ G
{{< /mermaid >}}

Per facilitar la contextualització, la següent taula indica les diferències claus:

| Aspecte           | Flux local                 | Flux CI/CD                     |
|:------------------|:---------------------------|:-------------------------------|
| Execució          | Manual                     | Automàtica per `push`/`merge`  |
| Entorn            | Màquina del desenvolupador | Servidor dedicat               |
| Credencials       | Fitxer `.env.prod`         | Bòveda del CI/CD               |
| Accés al clúster  | SSH directe                | Clau SSH del CI/CD             |
| Tests             | Opcionals                  | Obligatoris abans de desplegar |
| Rollback          | Manual                     | Pot ser automàtic              |

## Automatització

La creació d'una pipeline de CI/CD és la millor forma de posar una aplicació en marxa, però no és una tasca menor, motiu pel qual ho tractarem en un seguit d'articles separats. Mentres tant, com a primera passa i per no desviar-nos excessivament de l'àmbit de Docker Swarm, començarem fixant uns objectius bàsics:

1. Assegurar-nos de que el desplegament manual segueixi sempre una llista de passos clara i concisa.
2. Automatitzar alguns passos en el que anomenarem un "conducte local semiautomatitzat".

Assumint que ja hem inicialitzat el clúster i creat els secrets prèviament, quan fem feina sense CI/CD, el flux típic és:

1. Desenvolupar, provar i cometre els canvis al repositori.
2. Opcionalment, etiquetar la versió.
3. Construir la imatge de l'aplicació i pujar-la al registre.
4. Desplegar l'stack i verificar l'estat.

### Desplegament

Una vegada hem acabat de fer un seguit de canvis a la nostra aplicació i volem posar-los en producció, abans de començar el desplegament pròpiament dit, seguirem aquests passos:

1. Comprovar l'estat del repositori.
   ```bash
   git status
   ```
2. Si hi ha canvis sense cometre, farem commit.
   ```bash
   git add <ruta>
   git commit -m "Missatge de commit"
   ```
3. Si escau, etiquetarem la versió de l'aplicació.
   ```bash
   git tag 1.1.0
   git push --tags
   ```

A partir d'aquí, el desplegament d'una aplicació en un clúster de Docker Swarm segueix sempre la mateixa seqüència de passos:

1. Obtenir la versió (*tag* de Git o *hash* del commit).
   ```bash
   # Si hi ha un tag al commit actual, l'usa; sinó, usa el hash
   VERSION=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
   echo $VERSION
   ```
2. Construir la imatge.
   ```bash
   docker build -t myuser/myapp:$VERSION -f docker/app/Dockerfile .
   ```
3. Pujar la imatge al registre.
   ```bash
   docker push myuser/myapp:$VERSION
   ```
4. Desplegar l'stack al clúster.
   ```bash
   export DOCKER_HOST=ssh://root@aaa.bb.cc.10
   VERSION=$VERSION docker stack deploy -c docker-stack.yml myapp
   ```
5. Verificar que els serveis estan correctes.
   ```bash
   docker stack services myapp
   ```

### Scripting

Per evitar executar aquests passos manualment cada vegada, podem usar un script que els unifiqui:

```bash
#!/bin/bash
#
# deploy/deploy.sh
#
# Script de desplegament per a Docker Swarm
#
set -euo pipefail

MANAGER_HOST="root@aaa.bb.cc.10"

# Comprova que no hi ha canvis pendents
if [[ -n $(git status --porcelain) ]]; then
    echo "Error: Hi ha canvis sense cometre"
    exit 1
fi

# Obté la versió
VERSION=$( \
  git describe --tags --exact-match 2>/dev/null || \
  git rev-parse --short HEAD)
echo "Desplegant versió: $VERSION"

# Construeix i puja la imatge
docker build -t myuser/myapp:$VERSION -f docker/app/Dockerfile .
docker push myuser/myapp:$VERSION

# Desplega al clúster
export DOCKER_HOST=ssh://$MANAGER_HOST
VERSION=$VERSION docker stack deploy -c docker-stack.yml myapp

# Verifica
watch docker stack ps myapp
```

Per a usar aquest script primer cal fer-lo executable:

```bash
chmod +x deploy/deploy.sh
```

## Accés SSH

Al llarg de l'article i també en alguns scripts hem usat la variable d'entorn `DOCKER_HOST` per executar comandes Docker remotament. Això requereix:

1. Tenir accés SSH configurat amb claus.
2. Que l'usuari remot tengui permisos per executar Docker.

Per configurar l'accés a través de SSH, pren els següents tres passos com a referència:

1. Generar clau SSH
   ```bash
   ssh-keygen -t ed25519 -C "deploy@myapp"
   ```
2. Copiar la clau pública al manager
   ```bash
   ssh-copy-id root@aaa.bb.cc.10
   ```
3. Verificar l'accés
   ```bash
   ssh root@aaa.bb.cc.10 "docker info"
   ```

## Bones pràctiques

Per acabar, un recull de bones pràctiques d'aspecte general, a mode de resum:

1. No cometre mai credencials al repositori.
2. Usar claus SSH específiques per al CI/CD amb permisos mínims.
3. Rotar secrets periòdicament, especialment després de canvis de personal.
4. Revisar els logs de desplegament per detectar anomalies.
5. Mantenir còpies de seguretat dels secrets en una bòveda segura.

## Exercici pràctic

L'objectiu d'aquest exercici és dur a terme desplegaments des de l'entorn local amb un cert nivell d'automatització, com a pas intermig de cap a un conducte de CI/CD complet i modern.

Requisits:

* Un clúster Docker Swarm amb almanco 2 nodes.
* Accés SSH configurat amb claus al node manager.
* Un compte a Docker Hub (o un registre alternatiu).
* Git instal·lat a la màquina de desenvolupament.

Tasques:

1. **Preparar els scripts**:
   * Crea el directori `deploy/` al teu projecte.
   * Copia l'script `create-secrets.sh` i ajusta la llista `SECRETS`.
   * Copia l'script `deploy.sh` i ajusta les variables de configuració.
   * Fes els scripts executables amb `chmod +x deploy/*.sh`.

2. **Preparar la configuració**:
   * Crea el fitxer `.env.prod` a partir de `.env.example`.
   * Omple'l amb els valors reals, recuperats d'una bòveda.
   * Verifica que `.env.prod` està inclòs al `.gitignore`.

3. **Primer desplegament**:
   * Configura l'accés al clúster
     ```bash
     export DOCKER_HOST=ssh://root@aaa.bb.cc.10
     ```
   * Crea els secrets:
     ```bash
     deploy/create-secrets.sh .env.prod
     ```
   * Verifica que s'han creat:
     ```bash
     docker secret ls
     ```
   * Executa l'script de desplegament:
     ```bash
     deploy/deploy.sh
     ```
   * Verifica que l'aplicació funciona.

4. **Actualització**:
   * Modifica alguna cosa al codi.
   * Fes commit dels canvis.
   * Executa `deploy/deploy.sh` de nou.
   * Observa el rolling update (darrera comanda de l'script).
   * Verifica que el canvi s'ha aplicat.

5. **Desplegament amb versió etiquetada**:
   * Crea un tag git:
     ```bash
     git tag 1.1.0
     git push --tags
     ```
   * Executa `deploy/deploy.sh`.
   * Verifica que la imatge té l'etiqueta `1.1.0` al registre.

6. **Neteja** (opcional):
   * Elimina l'stack:
     ```bash
     docker stack rm myapp
     ```
   * Elimina els secrets manualment:
     ```bash
     docker secret rm secret_key postgres_user postgres_password
     ```
