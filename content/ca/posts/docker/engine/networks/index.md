---
title: "Xarxes Docker"
date: 2026-04-03
lastmod: 2026-04-03
description: "Xarxes Docker: tipus de xarxes, comunicació entre contenidors, DNS intern i aïllament"
summary: "Xarxes Docker: tipus de xarxes, comunicació entre contenidors, DNS intern i aïllament"
categories: ["teaching"]
tags: ["docker", "engine", "networking", "nginx", "python"]
series: ["Docker Engine"]
series_order: 6
weight: 60
slug: xarxes
---

Les xarxes Docker permeten crear i gestionar xarxes virtuals que habiliten la comunicació entre contenidors. Aquesta funcionalitat és essencial quan construïm aplicacions multi-contenidor, on diferents serveis (servidor web, aplicació, base de dades) necessiten comunicar-se entre ells de manera segura i aïllada.

En aquest article explorarem els tipus de xarxes disponibles, com crear-les i gestionar-les i com connectar contenidors per formar una aplicació completa.

## Xarxes per defecte

Quan instal·lam Docker, es creen automàticament tres xarxes:

```bash
docker network ls
```

La sortida de la comanda serà:

```
NETWORK ID     NAME      DRIVER    SCOPE
b7673e576242   bridge    bridge    local
4f8526c27950   host      host      local
f5a661f700d9   none      null      local
```

Cada xarxa té un propòsit diferent:

| Controlador | Descripció                                                           | Cas d'ús                                                  |
|-------------|----------------------------------------------------------------------|-----------------------------------------------------------|
| `bridge`    | Xarxa privada interna. Els contenidors poden comunicar-se entre ells | Aplicacions multi-contenidor en un sol host               |
| `host`      | El contenidor comparteix la xarxa de l'amfitrió directament          | Aplicacions que necessiten el màxim rendiment de xarxa    |
| `none`      | El contenidor no té accés a cap xarxa                                | Contenidors que processen dades sense necessitat de xarxa |

## La xarxa bridge

Quan executam un contenidor sense especificar cap xarxa, Docker el connecta a la xarxa `bridge` per defecte:

```bash
docker run --name nginx-test --detach nginx:1.29-alpine
docker inspect nginx-test --format '{{.NetworkSettings.IPAddress}}'
```

El contenidor rep una IP de la xarxa bridge (per exemple, `172.17.0.2`). Tanmateix, la xarxa bridge per defecte té una limitació important: **no proporciona resolució DNS automàtica pel nom del contenidor**.

```bash
docker run --rm alpine ping -c 2 nginx-test
```

Aquesta comanda fallarà amb "bad address 'nginx-test'" perquè la xarxa bridge per defecte no resol noms de contenidor.

Netejem abans de continuar:

```bash
docker rm --force nginx-test
```

## Xarxes d'usuari

Per superar les limitacions de la xarxa bridge per defecte, podem crear les nostres pròpies xarxes. Les xarxes definides per l'usuari proporcionen:

- Resolució DNS automàtica, de forma que els contenidors es poden trobar pel seu nom.
- Millor aïllament, car només els contenidors de la mateixa xarxa poden comunicar-se.
- Connexió i desconnexió en calent, car podem afegir o treure contenidors d'una xarxa sense aturar-los.

### Creació

Per a crear una nova xarxa usarem la comanda `docker network create`, passant el nom de la xarxa com a paràmetre:

```bash
docker network create webapp-network
```

Per defecte, Docker crea una xarxa de tipus `bridge` amb una subxarxa automàtica. Podem verificar-ho:

```bash
docker network inspect webapp-network \
  --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'
```

Si necessitam especificar la subxarxa usarem el paràmetre `--subnet` i, si escau, el paràmetre `--gateway`:

```bash
docker network create \
  --driver bridge \
  --subnet 172.28.0.0/16 \
  --gateway 172.28.0.1 \
  custom-network
```

### Gestió

De manera anàloga als volums, l'ordre `docker network` ofereix un conjunt de comandes per gestionar les xarxes.

| Comanda                                          | Descripció                              |
|--------------------------------------------------|-----------------------------------------|
| `docker network create <nom>`                    | Crea una xarxa nova                     |
| `docker network ls`                              | Llista totes les xarxes                 |
| `docker network inspect <nom>`                   | Mostra informació detallada             |
| `docker network rm <nom>`                        | Elimina una xarxa (ha d'estar buida)    |
| `docker network prune`                           | Elimina totes les xarxes no utilitzades |
| `docker network connect <xarxa> <contenidor>`    | Connecta un contenidor a una xarxa      |
| `docker network disconnect <xarxa> <contenidor>` | Desconnecta un contenidor d'una xarxa   |

## DNS intern

Vegem com funciona la resolució DNS amb un exemple pràctic. Crearem una xarxa i hi connectarem dos contenidors:

```bash
docker network create test-dns

docker run --name server-a \
  --network test-dns \
  --detach \
  alpine sleep 3600

docker run --name server-b \
  --network test-dns \
  --detach \
  alpine sleep 3600
```

Ara, des de `server-a`, podem fer ping a `server-b` pel seu nom:

```bash
docker exec server-a ping -c 3 server-b
```

La sortida serà:

```
PING server-b (172.20.0.3): 56 data bytes
64 bytes from 172.20.0.3: seq=0 ttl=64 time=0.089 ms
64 bytes from 172.20.0.3: seq=1 ttl=64 time=0.085 ms
64 bytes from 172.20.0.3: seq=2 ttl=64 time=0.087 ms
...
```

Docker gestiona automàticament la resolució DNS dins de la xarxa. Això és fonamental per a aplicacions on els serveis es referencien pel nom, e.g., una aplicació que es connecta a `postgres` o `redis`.

Netejem els contenidors creats i la xarxa abans de continuar:

```bash
docker rm --force server-a server-b
docker network rm test-dns
```

## Exemple pràctic

Construirem una aplicació web amb tres components:

1. **NGINX**: Servidor web que actua com a reverse proxy.
2. **Python**: Aplicació Python sobre HTTP.
3. **PostgreSQL**: Base de dades.

{{< mermaid >}}
flowchart LR
    subgraph Internet
        U[Usuari]
    end
    
    subgraph Docker Host
        subgraph webapp-net
            N[NGINX<br/>:80]
            A[App Python<br/>:8000]
            D[(PostgreSQL<br/>:5432)]
        end
    end
    
    U -->|:8080| N
    N -->|proxy_pass| A
    A -->|database_host| D
{{< /mermaid >}}

### Xarxa i volum

Abans d'executar contenidors necessitam crear les nostres xarxes i els nostres volums. En aquest cas, amb un de cada ens basta:

```bash
docker network create webapp-net
docker volume create webapp-pgdata
```

### Base de dades

El primer contenidor que necessitam crear és el de la base de dades:

```bash
docker run --name webapp-db \
  --network webapp-net \
  --volume webapp-pgdata:/var/lib/postgresql \
  --env POSTGRES_PASSWORD=webapp123 \
  --env POSTGRES_USER=webapp \
  --env POSTGRES_DB=webapp \
  --detach \
  postgres:18-alpine
```

Fixem-nos que **no publicam el port 5432**, és a dir, la base de dades només és accessible des de la xarxa interna `webapp-net`.

### Aplicació

Per a aquest exemple, usarem una imatge de demostració. En un cas real, construiríem la nostra pròpia imatge amb el nostre propi Dockerfile.

Començarem creant un subdirectori de desenvolupament al nostre directori de projectes:

```bash
mkdir --parents ~/Projects/webapp-demo
```

Llavors, a dins, crearem un fitxer de Python, anomenat `app.py`, amb un servidor HTTP que respongui amb un missatge:

```python
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
import socket

class Handler(BaseHTTPRequestHandler):

    def check_database(self, host: str, port: int = 5432) -> bool:
        """Comprova si el port de PostgreSQL és accessible."""
        try:
            with socket.create_connection((host, port), timeout=5):
                return True
        except (socket.timeout, ConnectionRefusedError):
            return False

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        dbhost: str = os.environ.get("DATABASE_HOST")
        response = {
            "message": "Hola des de Python!",
            "hostname": socket.gethostname(),
            "database_host": dbhost,
            "database_reachable": self.check_database(dbhost)
        }
        self.wfile.write(json.dumps(response).encode())

if __name__ == "__main__":
    server = HTTPServer(('0.0.0.0', 8000), Handler)
    print("Servidor escoltant al port 8000...")
    server.serve_forever()
```

Executam l'aplicació:

```bash
docker run --name webapp-app \
  --network webapp-net \
  --volume ~/Projects/webapp-demo:/app:ro \
  --workdir /app \
  --env DATABASE_HOST=webapp-db \
  --detach \
  python:3.13-slim \
  python app.py
```

L'aplicació es connecta al port de la base de dades usant el nom del contenidor `webapp-db` com a host. Docker resol aquest nom a la IP correcta dins de la xarxa.

### Proxy invers

Per al nostre proxy invers crearem un fitxer de configuració `nginx/default.conf` dins el directori del projecte:

```bash
mkdir --parents ~/Projects/webapp-demo/nginx
```

Una configuració bàsica d'NGINX per aquest exemple seria:

```nginx
upstream python {
    server webapp-app:8000;
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://python;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
```

Ja podem executar el contenidor amb NGINX:

```bash
docker run --name webapp-nginx \
  --network webapp-net \
  --volume ~/Projects/webapp-demo/nginx:/etc/nginx/conf.d:ro \
  --publish 8080:80 \
  --detach \
  nginx:1.29-alpine
```

### Verificació

Començam la verificació comprovant que tots els contenidors estan a la mateixa xarxa:

```bash
docker network inspect webapp-net \
  --format '{{range .Containers}}{{.Name}} {{end}}'
```

Hauria de mostrar:

```text
webapp-db webapp-app webapp-nginx
```

I continuant comprovant la comunicació entre els contenidors executant una petició HTTP:

```bash
curl --silent http://localhost:8080/ | jq
```

El resultat serà:

```json
{
    "message": "Hola des de Python!",
    "hostname": "abc123def456",
    "database_host": "webapp-db",
    "database_reachable": true
}
```

### Neteja

Per a netejar tots els contenidors, el volum i la xarxa podem usar les següents comandes:

```bash
docker rm --force webapp-nginx webapp-app webapp-db
docker network rm webapp-net
docker volume rm webapp-pgdata
rm -rf ~/Projects/webapp-demo
```

> El següent apartat fa ús d'aquests contenidors per a demostrar com inspeccionar i depurar les xarxes de Docker. Si vols executar les comandes, espera una mica a executar les comandes de neteja.

## Inspecció i depuració

Podem veure les xarxes d'un contenidor amb la següent comanda:

```bash
docker inspect webapp-app \
  --format '{{json .NetworkSettings.Networks}}' | jq
```

Podem veure els contenidors d'una xarxa amb la següent comanda:

```bash
docker network inspect webapp-net
```

Podem comprovar la connectivitat des de dins amb la següent comanda:

```bash
docker exec -it webapp-db sh -c "ping -c 2 webapp-app"
```

Podem verificar ports oberts des de dins d'un contenidor amb la següent comanda:

```bash
docker exec -it webapp-db bash \
  -c "(echo > /dev/tcp/webapp-nginx/80) && \
  echo 'obert' || echo 'tancat'"
```

## Connectar i desconnectar contenidors

Podem connectar un contenidor existent a una xarxa addicional sense aturar-lo:

```bash
docker network connect webapp-net existing-container
```

Això és útil, per exemple, per a:

- Afegir un contenidor de monitorització a una xarxa existent.
- Connectar temporalment un contenidor de depuració.
- Migrar contenidors entre xarxes.

Per desconnectar:

```bash
docker network disconnect webapp-net existing-container
```

## La xarxa host

El driver `host` elimina l'aïllament de xarxa entre el contenidor i l'amfitrió. El contenidor usa directament la interfície de xarxa de l'amfitrió:

```bash
docker run --rm --network host nginx:1.29-alpine
```

Amb `--network host`:

- El contenidor no obté una IP pròpia.
- El port 80 de NGINX està directament accessible a l'amfitrió (sense necessitat de `--publish`).
- No hi ha traducció de ports (NAT).

Casos d'ús:

- Aplicacions que necessiten el màxim rendiment de xarxa.
- Contenidors que necessiten veure tot el tràfic de xarxa de l'amfitrió.
- Situacions on la traducció de ports és problemàtica.

{{< alert >}}
La xarxa `host` només funciona a Linux. A MacOS i Windows, Docker s'executa dins d'una màquina virtual, per la qual cosa `--network host` connecta el contenidor a la xarxa de la VM, no a la de l'amfitrió real.
{{< /alert >}}

## La xarxa none

El driver `none` desconnecta completament el contenidor de qualsevol xarxa:

```bash
docker run --rm --network none alpine ip addr
```

El contenidor només tendrà la interfície de loopback (`lo`). Això és útil, per exemple, per a:

- Processar dades sensibles sense risc d'exfiltració per xarxa.
- Executar tasques que no necessiten connectivitat.
- Màxim aïllament per seguretat.

## Exercicis pràctics

Es proposen dos exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Xarxa amb múltiples contenidors**

1. Crea una xarxa anomenada `exercici-net`.
2. Executa un contenidor MariaDB anomenat `exercici-db` connectat a la xarxa, amb una base de dades `testdb`, usuari `testuser` i contrasenya `testpass`.
3. Executa un contenidor Adminer (`adminer:latest`) anomenat `exercici-adminer` connectat a la mateixa xarxa, publicant el port 8080.
4. Accedeix a Adminer des del navegador i connecta't a MariaDB usant el nom del contenidor com a servidor.
5. Crea una taula i insereix algunes dades per verificar la connexió.
6. Usa `docker network inspect` per veure els dos contenidors connectats.
7. Neteja tots els recursos.

> Pista: A Adminer, el camp "Server" ha de ser el nom del contenidor de MariaDB.

### Exercici 2

**Aïllament de xarxes**

1. Crea dues xarxes: `frontend-net` i `backend-net`.
2. Executa un contenidor PostgreSQL anomenat `db` connectat només a `backend-net`.
3. Executa un contenidor Alpine anomenat `app` connectat a ambdues xarxes (`frontend-net` i `backend-net`).
4. Executa un contenidor Alpine anomenat `web` connectat només a `frontend-net`.
5. Verifica que:
   - `app` pot fer ping a `db` (ambdós a `backend-net`)
   - `app` pot fer ping a `web` (ambdós a `frontend-net`)
   - `web` *no* pot fer ping a `db` (xarxes diferents)
6. Neteja tots els recursos.

> Pista: Pots connectar un contenidor a una segona xarxa amb `docker network connect`.
