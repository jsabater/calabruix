---
title: "Construcció d'imatges"
date: 2026-04-19
lastmod: 2026-04-19
description: "Construcció d'imatges personalitzades amb Docker Compose, multi-stage builds i bones pràctiques"
summary: "Construcció d'imatges personalitzades amb Docker Compose, multi-stage builds i bones pràctiques"
categories: ["teaching"]
tags: ["docker", "compose"]
series: ["Docker Compose"]
series_order: 5
weight: 50
slug: build-imatges
---

Fins ara hem fet feina amb imatges oficials disponibles a Docker Hub. Però en projectes reals sovint necessitam construir les nostres pròpies imatges per empaquetar aplicacions personalitzades. Docker Compose facilita aquest procés amb la clau `build`, que permet definir com construir imatges directament des del fitxer `compose.yaml`.

En aquest article aprendrem a construir imatges amb Compose, optimitzar-les amb multi-stage builds i aplicar les bones pràctiques que garanteixen imatges lleugeres, segures i eficients.

## Imatges pròpies

No sempre cal construir imatges personalitzades. Usam imatges oficials quan:

- L'aplicació ja existeix com a imatge (bases de dades, servidors web, eines).
- Només necessitam configurar l'aplicació via variables d'entorn o fitxers muntats.

Construïm imatges pròpies quan:

- Desenvolupam una aplicació que no existeix com a imatge.
- Necessitam dependències específiques no incloses a la imatge oficial.
- Volem empaquetar el codi font amb les seves dependències.
- Necessitam optimitzacions específiques per al nostre entorn.

## La clau `build`

La forma més senzilla d'usar `build` és indicar el directori que conté el `Dockerfile`:

```yaml
services:
  api:
    build: docker/api
    ports:
      - "3000:3000"
```

Això equival a executar `docker build docker/api` i usar la imatge resultant per al servei. Ara bé, si volem exercir més control, podem usar la sintaxi estesa:

```yaml
services:
  api:
    build:
      context: docker/api
      dockerfile: Dockerfile
      args:
        NODE_ENV: production
    image: myapp/api:1.0
    ports:
      - "3000:3000"
```

Les opcions usades són:

- `context`: Directori que conté els fitxers necessaris per a la construcció, que podem entendre com el context sota el qual s'executarà la construcció.
- `dockerfile`: Nom del Dockerfile (per defecte, `Dockerfile`).
- `args`: Arguments de construcció que es passen al Dockerfile.

A més, també podem especificar `target`, que permet construir una imatge amb una etapa diferent d'un multi-stage build (ho veurem més avall en aquest article).

La clau `image` és opcional però recomanable. Si la definim, la imatge construïda tendrà aquest nom i etiqueta. Si no, Compose genera un nom automàtic basat en el projecte i servei.

## Comandes

Docker Compose ofereix diverses comandes per gestionar la construcció d'imatges. Per a construir totes les imatges definides amb build usarem:

```bash
docker compose build
```

Si només volem construir la imatge d'un servei específic, podem usar:

```bash
docker compose build api
```

Si volem construir imatges sense fer ús de la memòria cau, podem usar:

```bash
docker compose build --no-cache
```

Per construir i arrencar els serveis usarem:

```bash
docker compose up --build
```

Finalment, podem usar `build` amb `--progress=plain` per veure el procés de construcció en detall:

```bash
docker compose build --progress=plain
```

La diferència entre `docker compose build` i `docker compose up --build` és important:

- `build`: Només construeix les imatges, no arrenca els serveis.
- `up --build`: Construeix les imatges (si cal) i després arrenca els serveis.

> Per defecte, `docker compose up` només construeix les imatges si no existeixen. Usa `--build` per forçar la reconstrucció.

## Arguments

Els arguments de construcció permeten parametritzar el `Dockerfile`. Es defineixen amb `ARG` al `Dockerfile` i es passen des del `compose.yaml`:

```dockerfile
# Dockerfile

# Versió de Node.js amb valor per defecte
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-alpine

# Entorn, amb valor per defecte
ARG NODE_ENV=development
ENV NODE_ENV=${NODE_ENV}
```

```yaml
# compose.yaml
services:
  api:
    build:
      context: docker/api
      args:
        # Sobreescrivim els valors per defecte
        NODE_VERSION: 24  
        NODE_ENV: production
```

Els arguments només estan disponibles durant la construcció. Si necessitam que un valor estigui disponible en temps d'execució, hem de convertir-lo en variable d'entorn amb `ENV`.

## Multi-stage builds

Els multi-stage builds permeten crear imatges optimitzades separant el procés de construcció en múltiples etapes. Cada etapa pot usar una imatge base diferent i només el resultat final s'inclou a la imatge definitiva.

### Una etapa

Sense multi-stage, una imatge per a una aplicació [Node.js](https://nodejs.org/) sol incloure:

- El codi font.
- Les dependències de producció (`node_modules`).
- Les dependències de desenvolupament (eines de build, compiladors).
- Fitxers temporals i cau.

Això resulta en imatges innecessàriament grans.

### Múltiples etapes

Amb multi-stage builds, separam les etapes de construcció dins el mateix `Dockerfile`:

```dockerfile
# Etapa 1: Construcció
FROM node:24-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm clean-install
COPY src ./src
RUN npm run build

# Etapa 2: Producció
FROM node:24-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm clean-install --only=production
COPY --from=builder /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

Vegem pas a pas què fa cada instrucció:

**Etapa 1 (builder):**

1. `FROM node:24-alpine AS builder` — Partim d'una [imatge amb Node.js](https://hub.docker.com/_/node) i li donam el nom `builder` per poder-la referenciar després.
2. `WORKDIR /app` — Cream el directori de feina i ens situam a dins.
3. `COPY package.json package-lock.json ./` — Copiam els fitxers que declaren les dependències del projecte.
4. `RUN npm clean-install` — Instal·lam totes les dependències (producció i desenvolupament) exactament com estan fixades a `package-lock.json`. La comanda `npm clean-install` és més ràpida i reproduïble que `npm install`.
5. `COPY src ./src` — Copiam tot el codi font de l'aplicació.
6. `RUN npm run build` — Executam l'script de construcció definit a `package.json`, que normalment compila el codi i genera els fitxers optimitzats al directori `dist/`.

**Etapa 2 (producció):**

1. `FROM node:24-alpine` — Partim d'una imatge neta, sense res de l'etapa anterior.
2. `COPY package.json package-lock.json ./` — Tornam a copiar els fitxers de dependències.
3. `RUN npm clean-install --only=production` — Instal·lam només les dependències de producció, excloent les eines de desenvolupament (compiladors, eines de test, etc.).
4. `COPY --from=builder /app/dist ./dist` — Copiam el codi compilat des de l'etapa `builder`. Aquesta és la clau del multi-stage: agafam només el resultat, no les eines.
5. `USER node` — Canviam a un usuari no privilegiat per seguretat.
6. `CMD ["node", "dist/index.js"]` — Definim la comanda per arrencar l'aplicació.

L'etapa final només conté les dependències de producció i el codi compilat. Les eines de build (TypeScript, Webpack, Vite, etc.) i els fitxers temporals queden a l'etapa `builder` i no s'inclouen a la imatge final.

Un dels avantatges dels multi-stage builds és la reducció de la mida de la imatge. Pots consultar-ho amb:

```bash
docker images --format "{{.Size}}\t{{.Repository}}:{{.Tag}}"
```

### Fixar l'etapa

Podem construir fins a una etapa específica amb `target`:

```yaml
services:
  api:
    build:
      context: docker/api
      target: builder
```

Això és útil per a desenvolupament, on podem voler una imatge amb les eines de build incloses.

## Exemple pràctic

Per demostrar i practicar la construcció d'imatges personalitzades amb multi-stage, vegem com crear una API REST amb [Express.js](https://expressjs.com/) i PostgreSQL per gestionar una llista de tasques. Abans de res, anem a crear el directori de feina:

```bash
mkdir --parents ~/Projects/tasks-api/api/src/middlewares
cd ~/Projects/tasks-api
```

### Estructura del projecte

L'estructura proposada del projecte és la següent:

```
tasks-api/
├── compose.yaml
├── .env
└── api/
    ├── Dockerfile
    ├── .dockerignore
    ├── package.json
    └── src/
        ├── app.js
        ├── db.js
        └── middlewares/
            └── logger.js
```

### Fitxer `.env`

El fitxer `.env` contendrà les credencials d'accés a la base de dades PostgreSQL i l'entorn d'execució:

```ini
# PostgreSQL
POSTGRES_USER=tasks
POSTGRES_PASSWORD=canvia-aquest-password
POSTGRES_DB=tasks

# API
NODE_ENV=production
```

### Fitxer `package.json`

El fitxer `api/package.json` conté la configuració del projecte de Node.js:

```json
{
  "name": "tasks-api",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node src/app.js",
    "dev": "node --watch src/app.js"
  },
  "dependencies": {
    "express": "^5.2.1",
    "pg": "^8.20.0"
  }
}
```

Tres aspectes a destacar:

1. 1. L'opció `type` amb valor `module` indica que usam ESModules (sintaxi `import`/`export`) en lloc de CommonJS (sintaxi `require`).
2. L'opció `scripts` defineix comandes personalitzades d'execució de l'aplicació.
3. L'aplicació té dues dependències, el framework web `express` i la llibreria `pg` per gestionar la base de dades PostgreSQL.

### Fitxer `db.js`

El mòdul `api/src/db.js` gestiona la connexió a PostgreSQL i les operacions amb la taula de tasques. Usam la llibreria `pg`, que és el client natiu de PostgreSQL per a Node.js.

```javascript
import pg from "pg";

/**
 * Pool de connexions a PostgreSQL.
 * Un pool manté múltiples connexions obertes i les reutilitza,
 * evitant el cost de crear una connexió nova per cada consulta.
 */
const pool = new pg.Pool({
  host: process.env.DB_HOST || "localhost",
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || "tasks",
  user: process.env.DB_USER || "tasks",
  password: process.env.DB_PASSWORD || "tasks",
});

/**
 * Inicialitza la base de dades creant la taula si no existeix.
 */
export async function initDB() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        completed BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log("Database initialized");
  } finally {
    client.release();
  }
}

/**
 * Retorna totes les tasques ordenades per data de creació.
 * @returns {Array<Object>} Llista de tasques
 */
export async function getTasks() {
  const result = await pool.query(
    "SELECT * FROM tasks ORDER BY created_at DESC"
  );
  return result.rows;
}

/**
 * Crea una nova tasca amb el títol indicat.
 * @param {string} title - Títol de la tasca
 * @returns {Object} La tasca creada amb tots els seus camps
 */
export async function createTask(title) {
  const result = await pool.query(
    "INSERT INTO tasks (title) VALUES ($1) RETURNING *",
    [title]
  );
  return result.rows[0];
}

/**
 * Marca una tasca com a completada pel seu identificador.
 * @param {number} id - Identificador de la tasca
 * @returns {Object|undefined} La tasca actualitzada, o undefined si no existeix
 */
export async function completeTask(id) {
  const result = await pool.query(
    "UPDATE tasks SET completed = TRUE WHERE id = $1 RETURNING *",
    [id]
  );
  return result.rows[0];
}

/**
 * Elimina una tasca pel seu identificador.
 * @param {number} id - Identificador de la tasca
 * @returns {Object|undefined} La tasca eliminada, o undefined si no existeix
 */
export async function deleteTask(id) {
  const result = await pool.query(
    "DELETE FROM tasks WHERE id = $1 RETURNING *",
    [id]
  );
  return result.rows[0];
}

export default pool;
```

> En projectes més grans, és habitual usar un ORM (Object-Relational Mapping) com Prisma, Sequelize o Drizzle per gestionar la base de dades. Aquí usem consultes SQL directes per claredat i perquè l'alumnat ja coneix SQL d'altres assignatures.

### Fitxer `logger.js`

El mòdul `api/src/middlewares/logger.js` defineix un middleware que registra cada petició HTTP a la consola. Els middlewares a Express són funcions que s'executen entre la recepció de la petició i l'enviament de la resposta.

```javascript
/**
 * Middleware que registra les peticions HTTP.
 * Mostra el mètode (GET, POST, DELETE, etc.) i la ruta sol·licitada.
 */
const loggerMiddleware = (req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.url}`);
  next();
};

export default loggerMiddleware;
```

### Fitxer `app.js`

El fitxer `api/src/app.js` és el punt d'entrada de l'aplicació. Configura el servidor Express, registra els middlewares i defineix els endpoints de l'API.

```javascript
import express from "express";
import { initDB, getTasks, createTask, deleteTask } from "./db.js";
import loggerMiddleware from "./middlewares/logger.js";

/**
 * Instància de l'aplicació Express.
 */
const app = express();
const PORT = process.env.PORT || 3000;

/**
 * Middlewares globals.
 * - express.json(): Permet rebre i parsejar JSON al cos de les peticions.
 * - loggerMiddleware: Registra cada petició a la consola.
 */
app.use(express.json());
app.use(loggerMiddleware);

/**
 * Endpoint principal. Retorna informació sobre l'API.
 */
app.get("/", (req, res) => {
  res.json({
    message: "Tasks API",
    version: "1.0.0",
    endpoints: {
      "GET /tasks": "Llista totes les tasques",
      "POST /tasks": "Crea una nova tasca",
      "DELETE /tasks/:id": "Elimina una tasca",
    },
  });
});

/**
 * GET /tasks - Retorna totes les tasques.
 */
app.get("/tasks", async (req, res) => {
  try {
    const tasks = await getTasks();
    res.json(tasks);
  } catch (error) {
    console.error("Error getting tasks:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /tasks - Crea una nova tasca.
 * Espera un cos JSON amb el camp "title".
 */
app.post("/tasks", async (req, res) => {
  const { title } = req.body;

  if (!title) {
    return res.status(400).json({ error: "Title is required" });
  }

  try {
    const task = await createTask(title);
    res.status(201).json({ message: "Task created", task });
  } catch (error) {
    console.error("Error creating task:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * PATCH /tasks/:id - Marca una tasca com a completada.
 */
app.patch("/tasks/:id", async (req, res) => {
  const id = parseInt(req.params.id);

  if (isNaN(id)) {
    return res.status(400).json({ error: "Invalid task ID" });
  }

  try {
    const task = await completeTask(id);
    if (!task) {
      return res.status(404).json({ error: "Task not found" });
    }
    res.json({ message: "Task completed", task });
  } catch (error) {
    console.error("Error updating task:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * DELETE /tasks/:id - Elimina una tasca pel seu identificador.
 */
app.delete("/tasks/:id", async (req, res) => {
  const id = parseInt(req.params.id);

  if (isNaN(id)) {
    return res.status(400).json({ error: "Invalid task ID" });
  }

  try {
    const task = await deleteTask(id);
    if (!task) {
      return res.status(404).json({ error: "Task not found" });
    }
    res.json({ message: "Task deleted", task });
  } catch (error) {
    console.error("Error deleting task:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * Inicialitza la base de dades i arrenca el servidor.
 */
initDB()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((error) => {
    console.error("Failed to initialize database:", error);
    process.exit(1);
  });
```

### Fitxer `.dockerignore`

El fitxer `api/.dockerignore` funciona com `.gitignore` però per a Docker. Exclou fitxers i directoris del context de construcció, reduint el temps de build i evitant incloure fitxers innecessaris a la imatge.

```
node_modules
npm-debug.log
.git
.gitignore
.env
*.md
```

En aquest exemple s'exclouen:

- `node_modules`: Les dependències instal·lades localment. S'instal·laran dins la imatge amb `npm clean-install`.
- `npm-debug.log`: Fitxer de log generat quan npm troba errors.
- `.git`: El directori de control de versions, innecessari dins la imatge.
- `.gitignore`: Fitxer de configuració de Git.
- `.env`: Variables d'entorn locals que poden contenir secrets. Les variables es passen via `compose.yaml`.
- `*.md`: Fitxers de documentació (`README.md`, `CHANGELOG.md`, etc.).

> Recorda que el `.dockerignore` ha d'estar al directori del context de build, és a dir, al mateix nivell que el `package.json`, no amb el `compose.yaml`.

### Fitxer `Dockerfile`

Com que la nostra aplicació és JavaScript pur i no requereix compilació, no necessitem un multi-stage build. El multi-stage és útil quan hi ha un pas de build que genera artefactes (com el directori `dist/`) i volem excloure les eines de compilació de la imatge final. En el nostre cas, un Dockerfile d'una sola etapa és suficient.

Per tant, el nostre fitxer `api/Dockerfile` queda així:

```dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm clean-install --only=production
COPY src ./src
USER node
EXPOSE 3000
CMD ["node", "src/app.js"]
```

Analitzem cada instrucció:

1. `FROM node:24-alpine` — Partim de la imatge oficial de Node.js basada en Alpine Linux.
2. `WORKDIR /app` — Cream el directori de feina i ens situam a dins.
3. `COPY package.json package-lock.json ./` — Copiam els fitxers de dependències abans que el codi font per aprofitar la memòria cau de Docker.
4. `RUN npm clean-install --only=production` — Instal·lam només les dependències de producció.
5. `COPY src ./src` — Copiam el codi font de l'aplicació.
6. `USER node` — Executam l'aplicació amb l'usuari `node`, que ja ve inclòs a les imatges oficials de Node.js.
7. `EXPOSE 3000` — Documentam el port que usa l'aplicació (no el publica, només informa).
8. `CMD ["node", "src/app.js"]` — Definim la comanda per arrencar l'aplicació.

### Fitxer `compose.yaml`

Finalment, el fitxer `compose.yaml` orquestra els dos serveis: l'API que construïm amb el nostre `Dockerfile` i la base de dades PostgreSQL que usa una imatge oficial.

```yaml
services:
  api:
    build:
      context: ./api
    image: tasks-api:1.0
    depends_on:
      db:
        condition: service_healthy
    environment:
      NODE_ENV: ${NODE_ENV}
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB}
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "3000:3000"
    restart: unless-stopped

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres-data:
```

Observa com el servei `api` usa `build.context` per indicar el directori que conté el Dockerfile, mentre que `db` usa directament una imatge oficial amb `image`. Quan definim ambdues claus (`build` i `image`) al servei `api`, la imatge construïda es guardarà amb el nom i etiqueta especificats.

### Arrencada

Usarem la comanda habitual per a arrencar els serveis:

```bash
docker compose up --build --detach
```

Verificam que els serveis funcionen:

```bash
docker compose ps
```

Si escau, també podem revisar els logs:

```bash
docker compose logs api
```

Una vegada arrencats els serveis, podem començar a provar l'API. Comencem creant un parell de tasques:

```bash
curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Aprendre Docker Engine"}'

curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Aprendre Docker Compose"}'

curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Aprendre Docker Swarm"}'

curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Tornar a veure The Expanse"}'
```

Ara ja podem llistar les tasques:

```bash
curl http://localhost:3000/tasks
```

També podem marcar una tasca com a completada:

```bash
curl -X PATCH http://localhost:3000/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
```

I, finalment, podem eliminar una tasca:

```bash
curl -X DELETE http://localhost:3000/tasks/1
```

## Bones pràctiques

Algunes recomanacions per construir imatges de manera eficient i segura.

**Ordre de les instruccions**

L'ordre de les instruccions al `Dockerfile` afecta directament l'eficiència de la memòria cau. Docker reutilitza capes anteriors si no han canviat. Ordena les instruccions de manco a més propenses a canviar:

```dockerfile
# 1. Imatge base (canvia rarament)
FROM node:24-alpine

# 2. Directori de feina (canvia rarament)
WORKDIR /app

# 3. Dependències (canvia quan actualitzam paquets)
COPY package.json package-lock.json ./
RUN npm clean-install --only=production

# 4. Codi font (canvia freqüentment)
COPY src ./src

# 5. Configuració d'execució
USER node
EXPOSE 3000
CMD ["node", "src/app.js"]
```

Amb aquest ordre, si només canvia el codi font, Docker reutilitza les capes 1, 2 i 3 i només reconstrueix a partir de la 4.

**El fitxer `.dockerignore`**

Inclou sempre un `.dockerignore` per excloure:

- El directori on s'instal·len les dependències localment, ja que es tornaran a instal·lar dins la imatge durant el build. Alguns exemples segons l'ecosistema:
  - Node.js: `node_modules/`
  - Python: `.venv/`, `__pycache__/`, `*.pyc`, `.eggs/`, `*.egg-info/`.
  - Java: `target/` (Maven), `build/` (Gradle)
  - PHP: `vendor/`
  - Ruby: `vendor/bundle/`
- Fitxers de control de versions (`.git`).
- Fitxers de configuració local (`.env`, `.env.local`).
- Documentació i fitxers innecessaris.
- Logs i fitxers temporals.

> Recorda que el `.dockerignore` ha d'estar al directori del context de build (el que especifiques a `build.context`), és a dir, al mateix nivell que el `package.json`, no amb el `compose.yaml`.

**Imatges base**

Prefereix imatges lleugeres com les variants `-alpine`:

| Imatge           | Mida aproximada |
|------------------|-----------------|
| `node:24`        | ~1.1 GB         |
| `node:24-slim`   | ~250 MB         |
| `node:24-alpine` | ~150 MB         |

Les imatges Alpine són més petites però usen `musl` en comptes de `glibc`, cosa que pot causar problemes amb algunes dependències natives. Si tens problemes, prova amb `-slim`.

**Usuari no privilegiat**

Mai executis aplicacions com a `root` dins el contenidor. Les imatges oficials de Node.js ja inclouen un usuari `node` que podem usar directament:

```dockerfile
USER node
```

Si uses una imatge base que no inclou un usuari no privilegiat, pots crear-lo:

```dockerfile
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup
USER appuser
```

**Usa CMD amb sintaxi exec**

Prefereix la sintaxi *exec* (amb claudàtors) per a la instrucció `CMD`:

```dockerfile
CMD ["node", "src/app.js"]
```

Evita la sintaxi *shell*

```dockerfile
CMD node src/app.js
```

La sintaxi *exec* executa el procés directament, sense passar per una *shell*. Això permet que els senyals del sistema (com `SIGTERM` per aturar el contenidor) arribin correctament al procés Node.js.

## Exercicis

Es proposen dos exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Afegir un frontend React**

L'equip de frontend ha preparat una aplicació React senzilla que consumeix l'API de tasques. Descarrega't [l'aplicació de frontend](/downloads/docker/compose/images/frontend.zip). {{< icon "download" >}}

La teva tasca és:

1. Descarrega i extreu el codi del frontend al directori `frontend/` dins el projecte.
2. Crea un `Dockerfile` multi-stage per al frontend que:
   - Etapa 1 (`builder`): Usa `node:24-alpine`, instal·la dependències i compila l'aplicació amb `npm run build`
   - Etapa 2: Usa `nginx:1.29-alpine` per servir els fitxers estàtics
3. Modifica el `compose.yaml` per afegir el servei `frontend` al port 8080.
4. Verifica que pots accedir al frontend a `http://localhost:8080/` i que es comunica correctament amb l'API.

> Pista: El resultat de `npm run build` es genera al directori `dist/`. NGINX serveix fitxers des de `/usr/share/nginx/html`.

{{< details summary="Respostes" >}}

L'estructura del projecte després d'afegir el frontend:

```
tasks-api/
├── compose.yaml
├── .env
├── api/
│   └── ...
└── frontend/
    ├── Dockerfile
    ├── .dockerignore
    ├── package.json
    ├── index.html
    ├── vite.config.js
    └── src/
        ├── main.jsx
        ├── App.jsx
        └── App.css
```

Crea el fitxer `frontend/.dockerignore`:

```
node_modules
dist
.git
.gitignore
*.md
```

Crea el fitxer `frontend/Dockerfile`:

```dockerfile
# Etapa 1: Construcció
FROM node:24-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm clean-install
COPY . .
RUN npm run build

# Etapa 2: Servir amb Nginx
FROM nginx:1.29-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Modifica el fitxer `compose.yaml` per afegir el servei frontend:

```yaml
services:
  api:
    build:
      context: ./api
    image: tasks-api:1.0
    depends_on:
      db:
        condition: service_healthy
    environment:
      NODE_ENV: ${NODE_ENV}
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB}
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "3000:3000"
    restart: unless-stopped

  frontend:
    build:
      context: ./frontend
    image: tasks-frontend:1.0
    depends_on:
      - api
    ports:
      - "8080:80"
    restart: unless-stopped

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres-data:
```

Construeix i arrenca tots els serveis:

```bash
docker compose up --build --detach
```

Verifica que els contenidors han arrencat:

```bash
docker compose ps
```

I, finalment, obre el navegador a `http://localhost:8080/` per veure l'aplicació completa.

{{< /details >}}

### Exercici 2

**Optimització d'un Dockerfile**

El següent Dockerfile funciona però té diversos problemes d'optimització. Identifica els problemes i reescriu-lo seguint les bones pràctiques:

```dockerfile
FROM node:19
WORKDIR /app
COPY . .
RUN npm install
RUN npm cache clean --force
EXPOSE 3000
CMD ["npm", "start"]
```

Problemes a identificar:

1. Quin tipus d'imatge base s'hauria d'usar?
2. Quin és el problema amb l'ordre de les instruccions?
3. Com es podria millorar la instal·lació de dependències?
4. Falta alguna cosa relacionada amb la seguretat?
5. Hi ha instruccions que es podrien combinar?

{{< details summary="Respostes" >}}

**Problemes identificats:**

1. **Imatge base**: Usa `node:19` (1.1 GB) en lloc de `node:24-alpine` (140 MB i LTS).
2. **Ordre de les instruccions**: Copia tot el codi abans d'instal·lar dependències, invalidant la cau cada vegada que canvia qualsevol fitxer.
3. **Instal·lació de dependències**: Usa `npm install` en lloc de `npm ci`, i instal·la dependències de desenvolupament.
4. **Seguretat**: No crea ni usa un usuari no privilegiat.
5. **Instruccions separades**: `npm install` i `npm cache clean` podrien combinar-se, però millor no fer `cache clean` amb `npm ci`.

**Dockerfile optimitzat:**

```dockerfile
# Etapa 1: Dependències
FROM node:24-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Etapa 2: Producció
FROM node:24-alpine
WORKDIR /app

# Copiar dependències i codi
COPY --from=deps /app/node_modules ./node_modules
COPY src ./src
COPY package.json ./

# Configuració
USER node
EXPOSE 3000
CMD ["node", "src/app.js"]
```

**Millores aplicades:**

- Imatge base `alpine` (molt més lleugera)
- Multi-stage build per separar construcció i execució
- `npm ci` per a instal·lacions reproduïbles
- `--only=production` per excloure dependències de desenvolupament
- Ordre optimitzat: primer `package.json`, després el codi
- Usuari no privilegiat per seguretat
- `CMD` executa directament `node` en lloc de `npm start` (un procés manco)

{{< /details >}}
