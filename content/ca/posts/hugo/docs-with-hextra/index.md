---
title: "Documentació tècnica amb Hugo i Hextra"
date: 2026-04-21
lastmod: 2026-04-30
description: "Guia per crear un website de documentació tècnica amb Hugo i el tema Hextra: instal·lació, configuració, creació de contingut i generació dels fitxers estàtics."
summary: "Crea un website de documentació tècnica professional amb Hugo i el tema Hextra, sense dependències externes ni eines addicionals."
categories: ["teaching"]
tags: ["hugo", "hextra", "docs", "ssg"]
slug: "docs-amb-hextra"
---

Aquest article forma part dels apunts de classe d’una unitat temàtica de l’assignatura Llenguatges de Marques i Sistemes de Gestió Empresarial del primer curs del CFGS en Administració de Sistemes Informàtics i Xarxes al CIFP Francesc de Borja Moll de Palma.

[Hugo](https://gohugo.io/) és un generador de llocs web estàtics (*static site generator*, SSG). A diferència dels sistemes de gestió de continguts tradicionals com WordPress, un SSG no necessita una base de dades ni un servidor d'aplicacions: pren els continguts escrits en Markdown, aplica una plantilla (el tema) i genera un conjunt de fitxers HTML, CSS i JavaScript llestos per servir. El resultat és un lloc web ràpid, segur i fàcil de mantenir.

Hugo destaca per la seva velocitat de generació, la seva portabilitat (és un binari únic sense dependències d'execució) i la seva compatibilitat multiplataforma. En aquest article aprendrem a usar-lo per crear un lloc web de documentació tècnica.

Com a tema usarem [Hextra](https://imfing.github.io/hextra/), un tema modern i actiu, dissenyat específicament per a llocs web de documentació. Funciona directament amb Hugo i [Git](https://git-scm.com/), sense requerir cap eina addicional.

> Existeixen altres temes de documentació per a Hugo, com ara [Lotus Docs](https://lotusdocs.dev/), [Docsy](https://www.docsy.dev/) o [Geekdocs](https://geekdocs.de/). Tot i que són opcions vàlides, cadascun d'ells requereix la instal·lació d'eines addicionals ([Go](https://golang.org/), [Node.js](https://nodejs.org/) o [npm](https://www.npmjs.com/)) per poder generar el lloc web. Per simplificar la posada en marxa, en aquest article ens centrarem en Hextra, que no té cap d'aquestes dependències.

## Instal·lació

Necessitam dues eines: Git i Hugo. Usant el terminal, comprova si ja les tens instal·lades abans de procedir:

```bash
git --version
hugo version
```

### Git

A distribucions Linux basades en Debian/Ubuntu usarem el gestor de paquets APT:

```bash
sudo apt install git
```

A macOS, executa la comanda següent al terminal per instal·lar les [Xcode Command Line Tools](https://developer.apple.com/xcode/resources/), que inclouen Git, i segueix les instruccions de l'assistent d'instal·lació que apareixerà:

```zsh
xcode-select --install
```

Finalment, a Windows, executa la comanda següent al terminal de PowerShell per instal·lar Git:

```powershell
winget install --id Git.Git -e --source winget
```

Si Winget no està disponible, descarrega l'instal·lador des de [la pàgina de Git](https://git-scm.com/download/win) i segueix l'assistent d'instal·lació.

### Hugo

Instal·larem sempre l'edició *extended* d'Hugo, que inclou suport per a [*](Sass)/[*](SCSS), necessari per a molts de temes moderns.

A distribucions Linux basades en Debian/Ubuntu, descarregam el paquet `hugo_extended_0.160.1_linux-amd64.deb` directament des de la [pàgina de releases de GitHub](https://github.com/gohugoio/hugo/releases/latest). El següent conjunt de comandes automatitzen la tasca (ajusta la versió a la primera línia, si escau):

```bash
HUGO_VERSION="0.160.1"
wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb \
    --output-document /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb
sudo dpkg --install /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb
rm /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb
```

A macOS, usa el navegador web per accedir a la [pàgina de releases d'Hugo a GitHub](https://github.com/gohugoio/hugo/releases/latest), descarrega el paquet d'instal·lació `hugo_extended_0.160.1_darwin-universal.pkg`, executa'l i segueix les instruccions d'instal·lació.

Alternativament, si tens [Homebrew](https://brew.sh/) instal·lat, pots instal·lar l'edició *extended* d'Hugo amb la comanda següent:

```zsh
brew install hugo
```

Finalment, a Windows, executa la comanda següent al terminal de PowerShell per instal·lar Hugo:

```powershell
winget install Hugo.Hugo.Extended
```

Si Winget no està disponible, descarrega l'arxiu `hugo_extended_0.160.1_windows-amd64.zip` des de [la pàgina de releases de GitHub](https://github.com/gohugoio/hugo/releases/latest), descomprimeix l'arxiu i copia el fitxer `hugo.exe` a la carpeta `C:\Program Files\Hugo`. Llavors afegeix la ruta al `PATH` a través de l'opció de menú `Configuració del sistema > Variables d'entorn > Path > Nou`.


Comprova la instal·lació:

```bash
hugo version
```

Hauries de veure una línia com ara `hugo v0.160.1+extended ...`.

## Inicialització

El directori de feina de referència al llarg de l'article serà `~/Projects/<nom-del-website>/` a Linux i macOS, o `%USERPROFILE%\Projects\<nom-del-website>\` a Windows.

La manera més senzilla de començar és crear un repositori Git local:

```bash
mkdir --parents ~/Projects/mywebsite
cd ~/Projects/mywebsite
git init
hugo new site . --force --format=yaml
```

Ara bé, si tens intenció de publicar el website més endavant, per exemple amb Cloudflare Pages o GitHub Pages, és convenient crear primer el repositori a GitHub i clonar-lo:

```bash
cd ~/Projects
git clone git@github.com:<usuari>/mywebsite.git
cd mywebsite
hugo new site . --force --format=yaml
```

> Per configurar l'accés SSH a GitHub, consulta la [documentació oficial](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).

**Estructura generada**

La comanda `hugo new site` crea l'estructura bàsica del projecte:

```
mywebsite/
├── archetypes/   → plantilles per a nous continguts
├── assets/       → recursos processats per Hugo (CSS, JS, IMG)
├── content/      → els teus continguts en Markdown
├── data/         → fitxers de dades (YAML, JSON, TOML)
├── i18n/         → traduccions de la interfície
├── layouts/      → plantilles HTML personalitzades
├── static/       → fitxers servits directament (ZIP, PDF)
├── themes/       → temes instal·lats
└── hugo.yaml     → fitxer de configuració principal
```

Els directoris que usarem més sovint són `content/` i `static/`, així com el fitxer `hugo.yaml`.

> Fixat que hem usat `--format=yaml` per generar el fitxer de configuració en format [*](YAML) en comptes de [*](TOML). Hextra documenta la seva configuració en YAML, de forma que és el format més còmode per a seguir aquest article.

## Instal·lar el tema

Usam Git submodule per instal·lar el tema. Aquest mètode afegeix el repositori del tema com un subrepositori dins del nostre projecte, sense necessitat d'eines addicionals.

> Hugo Modules és el mètode oficial recomanat per Hugo, però requereix tenir Go instal·lat al sistema. Git submodule funciona igual a totes les plataformes amb les dues eines que ja tenim: Git i Hugo. Per a l'objectiu d'aquest article, és la millor opció.

Des del directori arrel del projecte:

```bash
cd ~/Projects/mywebsite
git submodule add --branch main \
  https://github.com/imfing/hextra.git themes/hextra
```

Git clonarà el repositori d'Hextra a `themes/hextra/`.

Com a part de la configuració inicial que veurem una mica més avall, sobreescriurem el fitxer `hugo.yaml` sencer. Però, si volguéssim afegir el tema al fitxer de configuració ara mateix bastaria afegir una línia:

```bash
echo "theme: hextra" >> hugo.yaml
```

Cream el fitxer `.gitignore` per excloure els directoris generats:

```gitignore
# Hugo
.DS_Store
.hugo_build.lock
*.test
public/
resources/
```

I ja podem fer el primer commit:

```bash
git add .
git commit -m "Afegit tema Hextra com a submòdul"
```

Quan vulguis actualitzar Hextra a una versió més recent, executa les comandes següents:

```bash
git submodule update --remote --merge
git commit -am "Actualitzat el tema Hextra"
```

**Clonar el repositori**

Si en qualque moment vols clonar el repositori en un altre ordinador, cal tenir en compte que, quan es clona un repositori que conté submòduls, cal inicialitzar-los explícitament:

```bash
git clone --recurse-submodules \
  git@github.com:<usuari>/mywebsite.git
```

O, si ja has clonat sense l'opció dels submòduls, executa:

```bash
git submodule update --init
```

## Configuració inicial

Obrim `hugo.yaml` i substituim la configuració per defecte per una configuració mínima funcional:

```yaml
baseURL: "https://mywebsite.com/"
languageCode: "ca"
title: "El títol del meu website"
theme: hextra

# Menú de navegació principal (barra superior)
menu:
  main:
    - name: Documentació
      pageRef: /docs
      weight: 1
    - name: Cerca
      weight: 2
      params:
        type: search

# Paràmetres del tema
params:

  # Descripció del website (metadada SEO)
  description: "Documentació tècnica del mòdul ASIX"

  # Peu de pàgina
  footer:
    enable: true

  # Zoom d'imatges en fer clic
  imageZoom:
    enable: true
```

> Durant el desenvolupament local, Hugo sobreescriu automàticament el valor de `baseURL`, de forma que no importa quin valor hi posem per veure el website al navegador. Sí que importa quan generem els fitxers estàtics per publicar: en aquell moment cal que `baseURL` coincideixi amb l'adreça real del website.

Per veure el website al navegador mentre fem feina usarem el servidor de desenvolupament d'Hugo:

```bash
cd ~/Projects/mywebsite
hugo server --cleanDestinationDir --buildDrafts
```

Pots veure aquesta versió inicial a [http://localhost:1313/](http://localhost:1313/) des del teu navegador. Per aturar el servidor, prem `Ctrl+C` al terminal.

El servidor de desenvolupament observa els canvis als fitxers i recarrega el navegador automàticament. No cal aturar-lo i tornar-lo a arrencar cada vegada que fem un canvi.

Fixa't en els dos paràmetres que hem usat:

* `--buildDrafts`: Per veure contingut marcat com a esborrany, és a dir, encara no publicat.
* `--cleanDestinationDir`: Perquè el servidor de desenvolupament, en arrencar, faci una neteja inicial dels continguts de la carpeta de publicació.

> Per a una llista completa de paràmetres disponibles, consulta la [documentació de configuració d'Hextra](https://imfing.github.io/hextra/docs/guide/configuration/) i el [fitxer de configuració de referència](https://github.com/imfing/hextra/blob/main/docs/hugo.yaml) del tema.

## Crear contingut

Amb el tema instal·lat i el servidor de desenvolupament en marxa, és el moment de crear el contingut del website. En aquesta secció veurem com Hugo organitza els fitxers, quina estructura mínima ha de tenir un website de documentació i quins elements de contingut ric ens ofereix Hextra.

### Pàgines i seccions

Abans de crear contingut cal entendre com Hugo organitza els fitxers dins de `content/`.

Un **bundle** és un directori que conté un fitxer d'índex. N'hi ha de dos tipus:

- Les seccions, o **branch bundles**. Són directoris amb un fitxer  `_index.md` a dins. Poden contenir subseccions i altres pàgines. Hextra els representa com a entrades al menú lateral amb subapartats.
- Les pàgines fulla, o **leaf bundles**. Són directoris amb un fitxer `index.md`. No poden contenir subseccions. S'usen per a pàgines individuals amb recursos associats, com imatges o fitxers.

Per a la documentació tècnica, usam principalment **branch bundles** (amb fitxers `_index.md`), que permeten crear una jerarquia de seccions que Hextra representa automàticament al menú lateral esquerre.

> L'extensió `.md` s'usa per indicar que el fitxer es de tipus Markdown.

### Estructura mínima

Una forma d'estructurar inicialment els continguts podria ser per assignatura o projecte. Per exemple, vegem un exemple amb l'assignatura de xarxes:

```
content/
├── _index.md                  ← pàgina d'inici
└── docs/                      ← content type
    ├── _index.md              ← branch bundle
    └── xarxes/
        ├── _index.md          ← branch bundle
        ├── eines/
        │   ├── _index.md      ← branch bundle
        │   ├── nmap/
        │   │   └── index.md   ← leaf bundle
        │   └── wireshark/
        │       └── index.md   ← leaf bundle
        └── diagrames/
            └── index.md       ← leaf bundle
```

En aquest exemple:

- `_index.md` seria la pàgina d'inici del lloc web.
- `docs/_index.md` seria la portada de la documentació i podria contenir un índex de la documentació.
- `docs/xarxes/_index.md` seria la portada de l'assignatura de xarxes i podria contenir el context, els objectius i els requisits d'aquesta assignatura, així com un índex general de continguts.
- `docs/xarxes/eines/_index.md` seria la portada de la secció d'eines de xarxes i podria contenir l'índex d'eines amb una línia descriptiva per a cada una.
- `docs/xarxes/eines/nmap/index.md` podria contenir les instruccions d'instal·lació i ús de l'eina `nmap`.
- `docs/xarxes/eines/wireshark/index.md` podria contenir les instruccions d'instal·lació i ús de l'eina `wireshark`.
- `docs/xarxes/diagrames/index.md` podria contenir els apunts sobre com fer diagrames de xarxes.

Aquesta estructura de directoris i subdirectoris la podem estendre tant com vulguem. Si volem documentar més d'una assignatura, simplement afegim més directoris al mateix nivell:

```
content/docs/
├── _index.md
├── xarxes/
│   └── ...
└── bases-de-dades/
│   └── ...
└── sistemes-operatius/
    └── ...
```

> Si comences documentant una sola assignatura i el contingut no et sembla suficient per al lliurable, pots afegir-ne una altra sense haver de reestructurar res.

**Content type**

El subdirectori `docs/` dins `content/` no és una convenció arbitrària: Hextra reconeix aquesta secció com el contenidor de la documentació i hi aplica automàticament el layout corresponent, amb menú lateral, taula de continguts i navegació entre pàgines.

Tot el contingut que vulguis documentar ha d'estar dins `content/docs/`. Si necessitessis usar un nom de secció diferent, pots configurar-ho amb el paràmetre `params.docsRoot` al `hugo.yaml`, però per a la majoria de casos `docs/` és la solució més directa.

### Front matter

Cada fitxer Markdown comença amb un *front matter*, o bloc de metadades delimitat per `---`. Hugo i Hextra llegeixen aquests camps per configurar la pàgina.

En el cas d'una secció, o *branch bundle* (fitxer `_index.md`), el contingut mínim del *front matter* seria el següent:

```yaml
---
title: "Xarxes"
description: "Configuració i diagnòstic de xarxes TCP/IP."
weight: 1
---
```

El camp `weight` controla l'ordre de les seccions al menú lateral. Un valor menor apareix abans. Si dues seccions tenen el mateix `weight`, s'ordenen alfabèticament.

La portada o pàgina d'inici del lloc web (fitxer `content/_index.md`) també requerirà de metadades, però manco:

```yaml
---
title: "Documentació tècnica"
---
```

A continuació es mostren els camps de *front matter* més rellevants per a la documentació tècnica amb Hextra. Els camps marcats com a obligatoris són necessaris perquè Hugo processi la pàgina correctament:

| Camp          | Obligatori | Descripció                                                                                |
|---------------|:----------:|-------------------------------------------------------------------------------------------|
| `title`       | Sí         | Títol de la pàgina, visible al menú lateral i a la capçalera                              |
| `linkTitle`   | No         | Títol curt per al menú lateral si `title` és massa llarg                                  |
| `description` | No         | Descripció breu (metadada SEO i resum als llistats)                                       |
| `weight`      | No         | Ordre al menú lateral (valors menors apareixen primer)                                    |
| `date`        | No         | Data de creació; la pot generar Hugo automàticament                                       |
| `lastmod`     | No         | Data de darrera modificació, mostrada al peu si `displayUpdatedDate: true` al `hugo.yaml` |
| `draft`       | No         | Esborrany? Si `true` s'oculta la pàgina en la build de producció                          |
| `slug`        | No         | Personalitza la part final de la URL de la pàgina                                         |
| `tags`        | No         | Etiquetes temàtiques, visibles si `params.page.showTags: true` al `hugo.yaml`             |

### Escriure contingut

El contingut de cada pàgina s'escriu en Markdown estàndard. Hextra afegeix alguns components addicionals a través de shortcodes. Anem a veure alguns exemples de contingut:

**Blocs de codi amb sintaxi destacada**

Usant el triple accent greu podem escriure codi amb sintaxi destacada:

````markdown
```bash
sudo systemctl restart networking
```

```python
import socket
print(socket.gethostname())
```

```sql
SELECT * FROM hosts WHERE actiu = TRUE ORDER BY nom;
```
````

La sintaxi de destacat de codi la gestiona Hugo directament a través de [Chroma](https://github.com/alecthomas/chroma), que és la biblioteca de coloració sintàctica integrada. Hextra no hi afegeix res propi. La llista completa de llenguatges suportats la pots consultar a la [documentació oficial](https://gohugo.io/content-management/syntax-highlighting/#list-of-chroma-highlighting-languages). Són més de 200 llenguatges.

**Taules**

Podem crear taules amb la sintaxi Markdown que ja coneixem:

```markdown
| Comanda         | Descripció                              |
|-----------------|-----------------------------------------|
| `ip addr show`  | Mostra les interfícies de xarxa         |
| `ip route show` | Mostra la taula d'encaminament          |
| `ping -c 4 X`   | Envia 4 paquets ICMP a l'adreça X       |
| `traceroute X`  | Mostra el camí fins a l'adreça X        |
```

**Callouts**

Hextra suporta la sintaxi d'alertes i admonicions estil GitHub, que és portable i llegible fins i tot sense renderitzar:

```markdown
> [!NOTE]
> Informació útil que l'usuari hauria de saber.

> [!TIP]
> Consell per fer les coses millor o més fàcilment.

> [!WARNING]
> Informació important per evitar problemes.

> [!CAUTION]
> Acció que pot tenir conseqüències greus si s'executa incorrectament.
```

Alternativament, pots usar el shortcode propi d'Hextra:

```markdown
{{</* callout type="info" */>}}
  Informació útil que l'usuari hauria de saber.
{{</* /callout */>}}

{{</* callout type="warning" */>}}
  Acció que pot tenir conseqüències greus.
{{</* /callout */>}}
```

Els tipus disponibles són: `default`, `info`, `warning`, `error` i `important`.

**Imatges**

Tens dues opcions per afegir imatges. La primera és col·locar les imatges dins de la carpeta del *leaf bundle*, per exemple `docs/xarxes/diagrames/`. Llavors en faries referència directament:

```markdown
![Diagrama de xarxa](diagrama-xarxa.png)
```

I la segona és la de col·locar les imatges a la carpeta `static/`, per exemple `static/xarxes/diagrames/diagrama-xarxa.png`. Llavors en faries referència a través d'una ruta relativa:

```markdown
![Diagrama de xarxa](/xarxes/diagrames/diagrama-xarxa.png)
```

Pots crear l'estructura que vulguis dins de la carpeta `static/`. L'exemple anterior segueix la mateixa estructura de subdirectoris que la de la carpeta `docs/`, però no té perquè ser un criteri sempre vàlid.

En qualsevol cas, les imatges que fiquis dins de la mateixa carpeta que el document han de ser específiques d'aquell document, mentre que a la carpeta `static/` poden ser específiques o generals. En aquest segon cas, poden ser usades en màltiples documents.

**Enllaços interns**

Podem enllaçar els diferents continguts que anem generant, creant així un graf de navegació. Per fer-ho, usam la sintaxi Markdown que ja coneixem:

```markdown
Consulta l'apunt de [Wireshark](/docs/xarxes/eines/wireshark) per a la llista completa de paràmetres d'aquesta eina.
```

### Aparença

Per diferenciar el teu lloc web del dels companys, Hextra ofereix dues vies de personalització: paràmetres de configuració al `hugo.yaml` i CSS personalitzat per a canvis visuals més profunds.

**Paràmetres de configuració**

El peu de pàgina pot incloure un text de copyright. Afegeix el paràmetre `copyright` al `hugo.yaml`:

```yaml
params:
  footer:
    enable: true
    copyright: "© 2026 El teu nom — Llicència CC BY 4.0"
```

Editant el mateix fitxer, també pots afegir un logo a la barra de navegació superior:

```yaml
params:
  logo:
    path: images/logo.svg
    dark: images/logo-dark.svg  # opcional, mode fosc
```

Col·loca el fitxer `logo.svg` a `static/images/logo.svg`. Opcionalment, també el fitxer `logo-dark.svg` a `static/images/logo-dark.svg`.

Per a un *favicon* personalitzat, col·loca el fitxer `favicon.svg` a `static/`:

```bash
cp el-meu-favicon.svg static/favicon.svg
```

**CSS personalitzat**

Per a canvis visuals com el color principal o la font, Hextra carrega automàticament el fitxer `assets/css/custom.css`, si existeix. Crea'l amb un editor de CSS o des del terminal:

```bash
mkdir -p assets/css
touch assets/css/custom.css
```

Quant als colors, és habitual fer feina amb el format RGB (`rgb(255, 0, 0)`) o hexadecimal (`#ff0000`) quan s'aprèn CSS. En canvi, Hextra usa el format HSL (Hue, Saturation, Lightness), que té l'avantatge de ser més intuïtiu per a fer variacions d'un mateix color:

- El primer valor (*hue*) és el to cromàtic en graus sobre la roda de color (0 = vermell, 60 = groc, 120 = verd, 210 = blau, 270 = violeta).
- El segon és la saturació en percentatge.
- I el tercer és la lluminositat.

Canviant només el primer valor pots obtenir un color completament diferent mantenint la mateixa saturació i lluminositat, cosa molt pràctica per a aconseguir temes visuals coherents.

Afegeix el següent contingut al fitxer `assets/css/custom.css`:

```css
/*
  Color principal en mode clar i fosc.
  Modifica els valors HSL per obtenir el color que vulguis.
  Modifica --primary-hue per canviar el color principal.
  Exemples: blau (210), vermell (0), verd (140), taronja (30).
*/

:root {
  --primary-hue: 210deg;
  --primary-saturation: 80%;
  --primary-lightness: 40%;
}

.dark {
  --primary-hue: 210deg;
  --primary-saturation: 70%;
  --primary-lightness: 60%;
}
```

Per canviar la font del contingut, afegeix al mateix fitxer `assets/css/custom.css` una importació de Google Fonts i la declaració CSS corresponent. Per exemple, per usar [Inter](https://fonts.google.com/specimen/Inter):

```css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');

.content {
  font-family: "Inter", sans-serif;
}
```

Pots triar qualsevol font de [Google Fonts](https://fonts.google.com/). Substitueix `Inter` pel nom de la font que vulguis i adapta els pesos (`wght`) als que necessitis.

Has de tenir en compte que les fonts de Google Fonts es carreguen des d'internet, de manera que el website les necessitarà disponibles per mostrar-les correctament. Si es vol evitar aquesta dependència, pots descarregar la font i servir-la des de `static/fonts/`.

## Generar el lloc web

Quan el website estigui llest per lliurar o publicar, generarem els fitxers estàtics:

```bash
cd ~/Projects/mywebsite
hugo --cleanDestinationDir
```

Els fitxers HTML, CSS i JavaScript resultants es guarden a `public/`. El contingut d'aquesta carpeta és el que hauríem de pujar al nostre servidor web, e.g., Apache o NGINX.

Pots obrir el fitxer `public/index.html` directament al teu navegador, tot i que alguns recursos (fonts, scripts externs) no es carregaran correctament perquè Hugo els genera usant rutes absolutes. La forma recomanada de previsualitzar el resultat final és amb `hugo server` (sense fer ús de `--buildDrafts`) i accedint a la pàgina `http://localhost:1313/` en el navegador.

> Si vols publicar el website amb Cloudflare Pages, pots trobar els passos detallats en [aquesta secció](/posts/hugo/blog-with-blowfish/#cloudflare-pages) de l'article sobre com crear un blog amb Hugo i Blowfish. El procés és idèntic per a qualsevol tema d'Hugo.

## Exercicis

Es proposen dos exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Contingut i estructura**

L'objectiu d'aquest exercici és construir l'estructura de contingut del lloc web amb material real. Passos:

1. Crea l'estructura de directoris per a almanco una assignatura o projecte seguint l'estructura mínima recomanada o una estructura alternativa al teu gust.
2. Escriu el *front matter* i un contingut real a cada una de les seccions. El contingut ha de provenir d'una assignatura o projecte real del mòdul, no d'exemples genèrics.
3. Comprova que el website té, com a mínim, **4 seccions** visibles al menú lateral.
4. Comprova que el website té, com a mínim, per pàgina:
   - **200 mots** de text real
   - **2 blocs de codi** amb sintaxi destacada.
   - **1 taula**
   - **1 callout** (nota, avís o consell)
5. Verifica que `hugo server --cleanDestinationDir --buildDrafts` no dona errors i que totes les seccions apareixen al menú lateral.

> Si el menú lateral no mostra les teves seccions, comprova que els directoris intermedis usen _index.md (branch bundle) i les pàgines terminals usen index.md (leaf bundle).

### Exercici 2

**Personalització i lliurable**

L'objectiu d'aquest exercici és personalitzar el lloc web i generar els fitxers estàtics per a l'entrega. Passos:

1. Canvia el color principal del tema modificant `assets/css/custom.css` tal com s'explica a la secció de personalització. Tria un color diferent del que usen els companys de classe.
2. Configura el menú de navegació superior al `hugo.yaml` per reflectir l'estructura real del teu website.
3. Modifica el títol i la descripció del website al `hugo.yaml`.
4. Assegura't de que la generació dels fitxers estàtics funcioni:
   ```bash
   hugo --cleanDestinationDir
   ```
5. Si obris `public/index.html` al navegador, veuràs que el contingut del lloc web no es mostra correctament. Això és normal perquè Hugo ha usat rutes absolutes per les imatges, fitxers d'estils i scripts.
6. Crea un fitxer `README.md` a l'arrel del repositori seguint l'esquelet proporcionat a continuació.
7. Comprimeix el directori del projecte `mywebsite/` en un fitxer ZIP i lliura'l juntament amb el `README.md` a través de l'aula virtual.

Per a la correcció de l'exercici es descomprimirà l'arxiu ZIP i s'executarà la següent comanda:

```bash
cd mywebsite
hugo --cleanDestinationDir
```

Llavors s'usarà la URL http://localhost:1313/ per visualitzar el lloc web.

**Esquelet del README.md:**

````markdown
# Títol del website

## Descripció

Breu descripció del contingut documentat,
e.g., assignatures o projectes inclosos.

- `docs/<secció-1>/`: breu descripció
- `docs/<secció-2>/`: breu descripció
- `docs/<secció-3>/`: breu descripció

## Software

Indica les versions d'Hugo i d'Hextra instal·lades.
Inclou el teu sistema operatiu i altres detalls tècnics
que consideris adients.

## Canvis de configuració

Descriu els canvis que has fet al fitxer `hugo.yaml` i
al fitxer `assets/css/custom.css`:

- Títol
- Idioma
- Color principal
- Altres colors.
- Opcions de menú
- Altres

## Instruccions

Com previsualitzar el website. Assegura't de que les instruccions
proporcionades s'executen correctament.
````