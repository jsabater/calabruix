---
title: "Gestió de paquets i instal·lació de programari a Debian i Ubuntu"
date: 2026-11-09
lastmod: 2026-11-10
description: "Repositoris, paquets DEB, scripts instal·ladors, binaris i formats universals com a diferents maneres d'afegir programari a un sistema Debian o Ubuntu"
summary: "Les diferents maneres d'afegir programari a un sistema Debian o Ubuntu"
categories: ["teaching"]
tags: ["sysadmin", "debian", "ubuntu", "apt", "bash"]
slug: gestio-paquets
---

Aquest article forma part dels apunts de classe del mòdul *Implantació de sistemes operatius* del primer curs del CFGS en Administració de Sistemes Informàtics i Xarxes al CIFP [Francesc de Borja Moll](https://cifpfbmoll.eu/) de Palma.

Una de les primeres tasques de qualsevol administrador de sistemes és instal·lar programari. A Linux, la manera habitual és demanar el programari a un **gestor de paquets**, que el descarrega d'un **repositori** de confiança, comprova que no s'ha modificat, instal·la també tot el que necessita per funcionar (dependències) i, més endavant, l'actualitza juntament amb la resta del sistema.

Ara bé, no tot el programari que necessitarem és als repositoris de la distribució. Alguns fabricants publiquen el seu propi repositori, altres només ofereixen un paquet per descarregar, altres un script que ho fa tot i, altres, simplement, un fitxer executable. Cada via té avantatges, inconvenients i, sobretot, implicacions de seguretat diferents.

En aquest article recorrerem aquestes vies una a una, de la més integrada amb el sistema a la més manual:

1. Repositoris de la distribució, amb `apt`.
2. Paquets DEB descarregats a mà, instal·lats en local o en un servidor remot.
3. Paquets DEB que configuren el seu propi repositori.
4. Repositoris externs que configuram nosaltres, amb clau i fitxer de fonts.
5. Scripts instal·ladors executats amb `curl | sh`.
6. Binaris distribuïts dins un arxiu `.tar.gz`.
7. Formats universals: Snap, Flatpak i AppImage.

Acabarem amb un exemple de com automatitzar aquestes instal·lacions amb un script de BASH i amb un exercici per posar en pràctica tots els mètodes amb eines reals d'administració de sistemes.

Tots els exemples estan pensats per a Debian 13 Trixie i Ubuntu 26.04 LTS, sobre arquitectura `amd64` (també anomenada `x86_64`). Les eines de terminal es poden instal·lar a Ubuntu Server, en local o per SSH, mentre que els navegadors i les aplicacions de Flatpak i AppImage necessiten un escriptori, com el del portàtil[^1]. Les comandes que comencen amb `sudo` necessiten privilegis d'administrador[^2].

> A Ubuntu Server no existeix el directori `~/Downloads`, car només es crea en iniciar una sessió gràfica. Si escau, el cream primer amb `mkdir --parents ~/Downloads`.

[^1]: A Ubuntu 26.04, `sudo` i moltes de les eines bàsiques del sistema, com `ls`, `mkdir` o `sha256sum`, s'han substituït per noves implementacions escrites amb Rust (*sudo-rs* i *uutils*). Totes les opcions que usam en aquest article funcionen igual que a les versions originals.

[^2]: A Debian, si durant la instal·lació definim una contrasenya per a l'usuari `root`, el nostre usuari no s'afegeix al grup `sudo` i no podrà usar aquesta comanda. Ho podem arreglar entrant com a `root` amb `su -` i executant `apt install sudo` i `usermod --append --groups sudo <usuari>`. El canvi té efecte en tornar a iniciar sessió.

## Conceptes previs

Abans de començar, convé tenir clars uns quants termes que sortiran a cada apartat:

- Un **paquet** és un arxiu que conté un programa (o una biblioteca, o documentació) juntament amb les seves **metadades**: nom, versió, descripció, de quins altres paquets depèn i quins scripts s'han d'executar en instal·lar-lo o desinstal·lar-lo. A Debian i Ubuntu els paquets tenen extensió `.deb`.
- Un **repositori** és un servidor que publica una col·lecció de paquets i un **índex** que els descriu. L'índex està signat digitalment perquè puguem comprovar que ningú no l'ha manipulat.
- Les **dependències** són els altres paquets que un paquet necessita per funcionar. El gestor de paquets les resol i les instal·la automàticament.
- El binari `dpkg` és l'eina de baix nivell que instal·la, desinstal·la i consulta paquets `.deb` que ja tenim al disc. No descarrega res ni resol dependències.
- El binari `apt` és l'eina d'alt nivell que fa servir `dpkg` per sota: descarrega paquets dels repositoris, resol dependències i gestiona les actualitzacions.

## Repositoris de la distribució

És la via preferent sempre que el programari hi sigui. Els paquets els prepara i els manté l'equip de la distribució, estan provats amb la resta del sistema, reben actualitzacions de seguretat i s'actualitzen amb la mateixa comanda que tot el sistema.

Els repositoris configurats es defineixen a `/etc/apt/sources.list.d/`. A Debian 13, el format recomanat és un sol fitxer, `debian.sources`, en format `deb822`, amb un contingut semblant a aquest:

```bash
cat /etc/apt/sources.list.d/debian.sources
```

```text
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
```

Cada bloc defineix un repositori: el primer, el de la distribució i les seves actualitzacions (`trixie-updates`), i el segon, el de les actualitzacions de seguretat. Els **components** classifiquen els paquets segons la seva llicència:

| Component           | Contingut                                                                       |
| ------------------- | ------------------------------------------------------------------------------- |
| `main`              | Programari lliure, l'únic que forma part oficialment de Debian                  |
| `contrib`           | Programari lliure que depèn de programari que no ho és                          |
| `non-free`          | Programari que no és lliure                                                     |
| `non-free-firmware` | *Firmware* no lliure, necessari per a molts de dispositius (inclòs per defecte) |

A Ubuntu, el fitxer equivalent és `/etc/apt/sources.list.d/ubuntu.sources`, amb el mateix format. Els seus components són `main` i `restricted`, amb suport oficial de Canonical, i `universe` i `multiverse`, sense suport oficial i mantinguts per la comunitat. A `universe` hi trobarem moltes de les eines d'aquest article.

> Als sistemes més antics, els repositoris es definien al fitxer `/etc/apt/sources.list`, amb una línia per repositori que comença per `deb`. És el format que encara trobarem a molts de tutorials d'Internet, i també a alguns sistemes Debian 13, segons com s'hagin instal·lat o actualitzat. La comanda `apt modernize-sources` permet convertir el format antic al modern.

### Actualitzar el sistema

El primer que feim sempre és actualitzar l'**índex local de paquets**, és a dir, descarregar dels repositoris la llista actualitzada de paquets i versions disponibles. Aquesta comanda no instal·la ni actualitza res:

```bash
sudo apt update
```

Tot seguit actualitzam els paquets instal·lats a les darreres versions disponibles:

```bash
sudo apt --yes full-upgrade
```

`apt upgrade` actualitza els paquets però mai no n'instal·la de nous ni n'elimina cap, de manera que si una actualització ho necessita, la deixa pendent. `apt full-upgrade` sí que pot instal·lar o eliminar paquets per completar l'actualització. A molts de tutorials el trobarem amb el nom antic, `dist-upgrade`, que és equivalent.

> L'opció `--yes` respon «sí» automàticament a la pregunta de confirmació de modificació de l'estat del sistema.

Finalment, podem buidar la memòria cau de paquets descarregats, que es guarda a `/var/cache/apt/archives/` i pot ocupar força espai:

```bash
sudo apt clean
```

### Instal·lar paquets

Començarem instal·lant unes quantes eines bàsiques que usarem al llarg del curs:

```bash
sudo apt install ca-certificates curl fatrace git htop iotop-c jq net-tools python3-venv sysstat
```

| Paquet            | Per a què serveix                                                     |
| ----------------- | --------------------------------------------------------------------- |
| `ca-certificates` | Certificats de les autoritats de certificació, per a connexions HTTPS |
| `curl`            | Descarregar fitxers i fer peticions HTTP des de la terminal           |
| `fatrace`         | Mostrar en temps real quins processos accedeixen a quins fitxers      |
| `git`             | Control de versions                                                   |
| `htop`            | Monitor de processos interactiu                                       |
| `iotop-c`         | Monitor d'entrada/sortida a disc per procés                           |
| `jq`              | Processar dades en format JSON des de la terminal                     |
| `net-tools`       | Eines clàssiques de xarxa (`ifconfig`, `netstat`)[^3]                 |
| `python3-venv`    | Crear entorns virtuals de Python                                      |
| `sysstat`         | Estadístiques del sistema (`iostat`, `mpstat`, `sar`)                 |

[^3]: `net-tools` està en desús des de fa anys i ha estat substituït per `iproute2` (comandes `ip` i `ss`), que ja ve instal·lat al sistema. L'instal·lam perquè encara el trobarem a molts de servidors i documentació.

Fixau-vos que no hem indicat cap versió ni cap URL: `apt` ja sap d'on descarregar cada paquet i quines dependències ha d'instal·lar.

### Cerques i consultes

Si no sabem el nom exacte d'un paquet, el podem cercar:

```bash
apt search network monitor
apt search --names-only btop
```

Per veure'n la descripció, la mida i les dependències:

```bash
apt show btop
```

Per saber quina versió hi ha instal·lada i quina versió ofereix cada repositori, una comanda que usarem molt en aquest article:

```bash
apt policy btop
```

I, a més baix nivell, `dpkg` ens permet consultar què hi ha instal·lat al sistema:

| Comanda                     | Propòsit                             |
|-----------------------------|--------------------------------------|
| `dpkg --list \| grep htop`  | Està instal·lat htop?                |
| `dpkg --listfiles htop`     | Quins fitxers ha instal·lat?         |
| `dpkg --search /usr/bin/jq` | A quin paquet pertany aquest fitxer? |


### Desinstal·lar paquets

| Comanda                | Propòsit                                                   |
|------------------------|------------------------------------------------------------|
| `sudo apt remove htop` | Elimina el programa, conserva la configuració              |
| `sudo apt purge htop`  | Elimina el programa i la configuració del sistema          |
| `sudo apt autoremove`  | Elimina dependències que ja no necessita ningú             |
| `sudo apt autopurge`   | Elimina dependències no necessàries i la seva configuració |

`apt` és la comanda pensada per a ús interactiu: té barra de progrés, colors i missatges més clars, però els seus desenvolupadors no garanteixen que la sortida no canviï entre versions. Per això, dins els scripts usarem `apt-get`, que accepta les mateixes ordres principals (`update`, `install`, `remove`, `purge`, etc.) i té una interfície estable.

## Paquets DEB descarregats a mà

Quan un programa no és als repositoris de la distribució, o hi és amb una versió molt antiga, molts de projectes publiquen directament el paquet `.deb` a la seva pàgina web o a GitHub. En aquest cas, el descarregam i l'instal·lam nosaltres manualment.

Hi ha dues maneres d'instal·lar un `.deb` local:

```bash
sudo dpkg --install paquet.deb
sudo apt install ./paquet.deb
```

La diferència és important. `dpkg` instal·la el paquet però **no resol dependències**: si en falta alguna, l'instal·lació queda a mitges i ho haurem d'arreglar amb `sudo apt --fix-broken install`. En canvi, `apt` llegeix les dependències del paquet i les descarrega dels repositoris abans d'instal·lar-lo. Per això, en general, **preferirem `apt install ./paquet.deb`**.

El `./` és imprescindible. Sense, `apt` interpreta `paquet.deb` com el nom d'un paquet dels repositoris i no el troba. Amb un camí (`./`, `~/Downloads/`, `/tmp/`, etc.) entén que és un fitxer local.

Hem de tenir en compte, però, que un paquet instal·lat així **no s'actualitzarà** amb `apt full-upgrade`, perquè no prové de cap repositori que `apt` conegui. Quan surti una versió nova, haurem de repetir el procés.

**RustNet**

[RustNet](https://github.com/domcyrus/rustnet) és un monitor de connexions de xarxa per a la terminal: mostra quins processos tenen connexions obertes, amb quines adreces i ports, i quin protocol usen.

Obrim la [pàgina de la darrera versió](https://github.com/domcyrus/rustnet/releases/latest), desplegam l'apartat *Assets* i descarregam `Rustnet_LinuxDEB_amd64.deb` a `~/Downloads`. Abans d'instal·lar-lo, emperò, cal comprovar, mitjançant sumes de comprovació, que el fitxer descarregat és exactament el que ha publicat el projecte.

Una **suma de comprovació** (*checksum*) és una cadena que s'obté aplicant una funció d'empremta electrònica, o *hash*, al contingut d'un fitxer. Si canvia un sol bit del fitxer, la suma canvia completament. Si el projecte publica la suma SHA-256 de cada fitxer i nosaltres la calculam sobre el fitxer descarregat, podem comprovar que la descàrrega no s'ha corromput ni ha estat manipulada pel camí.

GitHub mostra la suma SHA-256 de cada fitxer al costat del seu nom, a l'apartat *Assets* de cada versió. La calculam sobre el nostre fitxer i comparam:

```bash
sha256sum ~/Downloads/Rustnet_LinuxDEB_amd64.deb
```

Comparar dues cadenes de 64 caràcters a ull és fàcil d'errar. És millor deixar que ho faci `sha256sum` amb l'opció `--check`, passant-li la suma esperada i el nom del fitxer separats per **dos espais**:

```bash
cd ~/Downloads
echo "<suma-sha256-de-github>  Rustnet_LinuxDEB_amd64.deb" | sha256sum --check
```

Si tot és correcte, veurem `Rustnet_LinuxDEB_amd64.deb: OK`.

> Una suma de comprovació garanteix la **integritat** del fitxer, però no la seva **autenticitat**: si un atacant controlàs el servidor, podria canviar alhora el fitxer i la suma. Per garantir l'autenticitat calen signatures digitals, com les que veurem més endavant, o els fitxers `.sig` que publiquen alguns projectes.

Ara sí, l'instal·lam:

```bash
sudo apt install ~/Downloads/Rustnet_LinuxDEB_amd64.deb
```

RustNet necessita permisos especials per capturar paquets de xarxa. En comptes d'executar-lo sempre amb `sudo`, li podem atorgar només les **capacitats** (*capabilities*) de Linux que necessita: `cap_net_raw` per llegir paquets de xarxa, i `cap_bpf` i `cap_perfmon` per usar [*](eBPF). L'script de post-instal·lació del paquet intenta fer-ho automàticament, i ho comprovam amb `getcap`:

```bash
getcap $(which rustnet)
```

Si no surt res, les atorgam a mà:

```bash
sudo setcap 'cap_net_raw,cap_bpf,cap_perfmon+eip' $(which rustnet)
```

I ja el podem executar com a usuari normal[^4]:

```bash
rustnet
```

[^4]: A Debian, el nucli restringeix per defecte l'accés als esdeveniments de rendiment (`kernel.perf_event_paranoid=3`), i RustNet pot necessitar rebaixar aquest valor a `2` per usar [*](eBPF). La [guia d'instal·lació](https://github.com/domcyrus/rustnet/blob/main/INSTALL.md) del projecte n'explica els detalls.

**Fastfetch**

[Fastfetch](https://github.com/fastfetch-cli/fastfetch) mostra un resum del sistema a la terminal: distribució, nucli, maquinari, memòria, escriptori, etc. És ideal per identificar d'un cop d'ull una màquina quan hi entram per SSH.

Aquesta vegada no usarem el navegador. GitHub ofereix una URL especial que sempre apunta al fitxer de la darrera versió, sempre que el nom del fitxer no inclogui el número de versió:

```text
https://github.com/<usuari>/<projecte>/releases/latest/download/<fitxer>
```

Podem descarregar-lo amb `curl`. L'opció `--location` (`-L`) és necessària perquè GitHub respon amb una redirecció cap al servidor on es guarda realment el fitxer:

```bash
curl --location --output ~/Downloads/fastfetch-linux-amd64.deb \
  https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb
```

O bé amb `wget`, que segueix les redireccions per defecte:

```bash
wget --output-document=$HOME/Downloads/fastfetch-linux-amd64.deb \
  https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb
```

> Fixau-vos que amb `wget` hem escrit `$HOME` en comptes de `~`. La shell només substitueix (expandeix) `~` pel directori personal quan apareix al principi d'una paraula, i `--output-document=~/...` no ho és. `$HOME` funciona a qualsevol posició.

Comprovam la suma (la trobam també a l'apartat *Assets* de la [darrera versió](https://github.com/fastfetch-cli/fastfetch/releases/latest)) i l'instal·lam:

```bash
cd ~/Downloads
echo "<suma-sha256>  fastfetch-linux-amd64.deb" | sha256sum --check
sudo apt install ./fastfetch-linux-amd64.deb
fastfetch
```

> Fastfetch també és als repositoris de les versions recents de Debian i Ubuntu, normalment amb una versió més antiga. Ho podeu comprovar amb `apt policy fastfetch`. Si una eina és als repositoris i la versió ens basta, sempre és preferible instal·lar-la per aquesta via.

**En un servidor remot**

Habitualment instal·larem programari no només al nostre portàtil, sinó en servidors als quals accedim per SSH i que no tenen entorn gràfic. Tenim dues opcions.

La primera és **descarregar el paquet directament al servidor**, si té accés a Internet. Hi entram per SSH i repetim les mateixes comandes:

```bash
ssh usuari@servidor
wget --output-document=/tmp/fastfetch-linux-amd64.deb \
  https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb
sudo apt install /tmp/fastfetch-linux-amd64.deb
```

La segona és **copiar el paquet des del nostre equip** amb `scp` i instal·lar-lo remotament amb `ssh`. És útil quan el servidor no té accés a Internet o quan volem instal·lar exactament el mateix fitxer que ja hem verificat:

```bash
scp ~/Downloads/fastfetch-linux-amd64.deb usuari@servidor:/tmp/
ssh -t usuari@servidor 'sudo apt install --yes /tmp/fastfetch-linux-amd64.deb'
ssh usuari@servidor 'rm /tmp/fastfetch-linux-amd64.deb'
```

L'opció `-t` de `ssh` reserva una terminal al servidor, necessària perquè `sudo` ens pugui demanar la contrasenya.

## Autoconfiguració de repositoris

Alguns fabricants resolen el problema de les actualitzacions d'una manera enginyosa: el paquet `.deb` que descarregam, a més d'instal·lar el programa, **afegeix el repositori del fabricant** al sistema, inclosa la clau. A partir d'aquí, les noves versions arribaran amb el `apt full-upgrade` habitual, com qualsevol altre paquet.

És el cas de navegadors com Vivaldi, Google Chrome o Microsoft Edge. Farem la prova amb el primer descarregant el paquet Debian des de la [pàgina de descàrrega de Vivaldi](https://vivaldi.com/download/) i, tot seguit, l'instal·lant-lo:

```bash
sudo apt install ~/Downloads/vivaldi-stable_*_amd64.deb
```

> L'asterisc ens estalvia escriure el número de versió, que forma part del nom del fitxer.

Ara comprovam què ha fet l'instal·lació, a més d'instal·lar el navegador:

```bash
ls -l /etc/apt/sources.list.d/
cat /etc/apt/sources.list.d/vivaldi*
ls -l /usr/share/keyrings/
```

Hi trobarem un fitxer nou que defineix el repositori de Vivaldi i una clau pública nova, que `apt` usarà per verificar la signatura dels paquets d'aquest repositori. Si ara executam `sudo apt update`, veurem que `apt` també consulta `repo.vivaldi.com`.

> Aquesta comoditat té un preu: en instal·lar el paquet hem executat amb privilegis de `root` els scripts del fabricant, que han modificat la configuració d'`apt`, i a partir d'ara acceptarem com a vàlid qualsevol paquet que aquest fabricant publiqui al seu repositori. Només ho hem de fer amb fabricants en què confiem.

## Repositoris externs configurats a mà

Altres fabricants no distribueixen cap `.deb` per descarregar, sinó que ens demanen que afegim nosaltres el seu repositori. El procés sempre té les mateixes passes:

1. Descarregar la **clau pública** amb què el fabricant signa el repositori.
2. Afegir el **fitxer de fonts** que descriu el repositori, indicant quina clau l'ha de validar.
3. Actualitzar l'índex de paquets.
4. Instal·lar el paquet.

[*](GPG) és una implementació lliure de l'estàndard OpenPGP de criptografia asimètrica. Cada fabricant té un **parell de claus**: una **clau privada**, que guarda en secret i amb la qual signa l'índex del repositori, i una **clau pública**, que distribueix lliurement i amb la qual comprovam aquesta signatura.

Si la signatura no és vàlida, perquè l'índex s'ha modificat o perquè no l'ha signat la clau esperada, `apt update` mostra un error i no usa aquell repositori. Així, a diferència de la suma de comprovació de l'apartat anterior, la signatura garanteix també l'**autenticitat**: només qui té la clau privada pot signar.

Les claus públiques dels repositoris externs es guarden habitualment a `/usr/share/keyrings/` o a `/etc/apt/keyrings/`, i cada repositori indica explícitament amb quina clau s'ha de validar. Així, la clau d'un fabricant només serveix per al seu repositori i no per a qualsevol altre[^5].

[^5]: A molts de tutorials antics encara trobarem la comanda `apt-key add`, que afegia les claus a un clauer global vàlid per a tots els repositoris. Està obsoleta, perquè qualsevol clau afegida així podia validar paquets de qualsevol repositori, i a les versions actuals de Debian i Ubuntu ja no existeix.

**Brave**

Seguim les [instruccions oficials](https://brave.com/linux/) per instal·lar el navegador Brave. Necessitam `curl`, que ja hem instal·lat al primer apartat.

Primer descarregam la clau pública i la guardam al directori de claus:

```bash
sudo curl --fail --silent --show-error --location \
  --output /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
```

A les instruccions oficials veurem aquestes opcions en la forma curta, `-fsSLo`: `--fail` fa que `curl` acabi amb error si el servidor respon amb un error HTTP (en comptes de desar la pàgina d'error com si fos la clau), `--silent` amaga la barra de progrés, `--show-error` mostra els errors tot i el mode silenciós, `--location` segueix redireccions i `--output` indica on desar el fitxer.

Tot seguit descarregam el fitxer de fonts del repositori:

```bash
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
  https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
```

Val la pena mirar-ne el contingut:

```bash
cat /etc/apt/sources.list.d/brave-browser-release.sources
```

Veurem que té el mateix format `deb822` que el fitxer `debian.sources` del primer apartat, amb un camp `Signed-By` que apunta a la clau que acabam de descarregar.

Actualitzam l'índex de paquets, perquè `apt` conegui els paquets del nou repositori, i instal·lam el navegador:

```bash
sudo apt update
sudo apt install brave-browser
```

Si no haguéssim sabut el nom exacte del paquet, l'hauríem pogut cercar un cop actualitzat l'índex:

```bash
apt search brave browser
apt policy brave-browser
```

Ara Brave s'actualitzarà amb la resta del sistema, exactament igual que Vivaldi. La diferència és que aquí hem fet nosaltres, de manera explícita, el que a Vivaldi feia el paquet sense que ho veiéssim.

## Scripts instal·ladors

Molts de projectes ofereixen una sola línia per instal·lar el seu programari:

```bash
curl -fsSL https://exemple.com/install.sh | sh
```

`curl` descarrega un script i, amb la canonada (`|`), el passa directament a la shell, que l'executa. És molt còmode, perquè l'script detecta el sistema operatiu i l'arquitectura, descarrega el fitxer adequat i el deixa a lloc. Però vol dir **executar a la nostra màquina un codi que no hem llegit**, i si a la línia hi ha `sudo`, executar-lo com a `root`.

Per això, la bona pràctica d'un administrador és **descarregar primer l'script, llegir-lo i executar-lo després**. No cal entendre cada línia, però sí saber què descarregarà, on ho instal·larà, si modificarà fitxers de configuració i si comprova el que descarrega.

El directori habitual, i desitjable, d'instalació de binaris és `~/.local/bin` que, en cas d'existir, ja forma part del `PATH`:

```bash
mkdir --parents ~/.local/bin
```

**Portop**

[Portop](https://github.com/padovanl/portop) és un monitor de ports a la terminal: mostra quins processos escolten a quins ports i quines connexions tenen obertes. La instal·lació que proposa el projecte és:

```bash
curl -fsSL https://raw.githubusercontent.com/padovanl/portop/main/install.sh | sh
```

Abans d'executar-la, descarregam l'script i el llegim:

```bash
curl --fail --silent --show-error --location --output /tmp/portop-install.sh \
  https://raw.githubusercontent.com/padovanl/portop/main/install.sh
less /tmp/portop-install.sh
```

Si el llegim amb calma, veurem que l'script:

- Detecta el sistema operatiu i l'arquitectura amb `uname`.
- Consulta a l'API de GitHub quina és la darrera versió, tret que li indiquem una versió concreta amb la variable d'entorn `PORTOP_VERSION`.
- Descarrega l'arxiu `.tar.gz` i el fitxer `checksums.txt`, i **es nega a instal·lar res si la suma no coincideix**.
- Instal·la el binari a `/usr/local/bin` si l'executam com a `root`, o a `~/.local/bin` si l'executam com a usuari normal (configurable amb `PORTOP_INSTALL_DIR`).
- No modifica cap fitxer de configuració de la shell, però ens avisa si el directori d'instal·lació no és al `PATH`.

És un script ben fet. Com que no necessita `root` per instal·lar-se a `~/.local/bin`, l'executam com a usuari normal:

```bash
sh /tmp/portop-install.sh
rm /tmp/portop-install.sh
```

Les variables d'entorn es poden definir just davant la comanda, per exemple per instal·lar una versió concreta:

```bash
PORTOP_VERSION=v0.4.0 sh /tmp/portop-install.sh
```

> Igual que amb els `.deb` descarregats a mà, el que instal·la un script no s'actualitza amb `apt`. Haurem de tornar a executar l'script quan vulguem una versió nova, i desinstal·lar-ho a mà si ja no ho volem.

## Binaris dins un arxiu

Moltes eines modernes, sobretot les escrites amb C, C++, Go o Rust, es compilen com un **binari autònom**: un sol fitxer executable que no depèn de cap biblioteca del sistema. Els projectes el distribueixen comprimit dins un arxiu `.tar.gz` i la instal·lació consisteix a descarregar-lo, verificar-lo, extreure'l i deixar-lo en un directori del `PATH`.

Com hem dit abans, per a programari que només usarà el nostre usuari, el lloc adequat és `~/.local/bin`. Té dos avantatges: no necessitam `sudo` per instal·lar-hi res i no interferim amb els fitxers que gestiona `apt` (que són a `/usr/bin`) ni amb els que instal·la l'administrador per a tothom (que solen anar a `/usr/local/bin`).

A Debian i Ubuntu, el fitxer `~/.profile` afegeix `~/.local/bin` al `PATH` en iniciar sessió, **però només si el directori ja existeix**. Si no existia, el cream i tancam i tornam a obrir la sessió (o carregam `~/.profile` a mà):

```bash
mkdir --parents ~/.local/bin
source ~/.profile
echo $PATH
```

**Netwatch**

[Netwatch](https://github.com/matthart1983/netwatch) és un monitor de xarxa semblant a RustNet: mostra interfícies, connexions i tràfic per procés[^6].

[^6]: Netwatch també publica el seu propi repositori `apt`, igual que Brave. Aquí l'instal·lam a partir del binari per practicar aquest mètode.

Al principi de les comandes definim una variable amb la versió que volem instal·lar. Així, si en volem una altra, només cal canviar una línia. Feim feina dins un directori temporal creat amb `mktemp`, per no deixar fitxers escampats:

```bash
NW_VERSION=0.40.0
cd "$(mktemp --directory)"
wget "https://github.com/matthart1983/netwatch/releases/download/v${NW_VERSION}/netwatch-linux-x86_64.tar.gz"
wget "https://github.com/matthart1983/netwatch/releases/download/v${NW_VERSION}/SHA256SUMS"
sha256sum --ignore-missing --check SHA256SUMS
```

El fitxer `SHA256SUMS` conté la suma de tots els fitxers de la versió. Amb `--ignore-missing`, `sha256sum` comprova només els que tenim descarregats i ignora la resta. Si la verificació és correcta, extreim el binari i l'instal·lam:

```bash
tar --extract --gzip --file=netwatch-linux-x86_64.tar.gz netwatch-linux-x86_64
mv netwatch-linux-x86_64 ~/.local/bin/netwatch
chmod +x ~/.local/bin/netwatch
```

L'arxiu conté un sol fitxer, `netwatch-linux-x86_64`, que en moure'l a `~/.local/bin` reanomenam a `netwatch`. Amb `chmod +x` ens asseguram que té permís d'execució.

Com RustNet, Netwatch necessita capacitats especials per capturar paquets. Sense, funciona igualment però amb menys informació:

```bash
sudo setcap 'cap_net_raw,cap_bpf,cap_perfmon+eip' ~/.local/bin/netwatch
netwatch
```

> Les capacitats es guarden com un atribut del fitxer. Quan actualitzem Netwatch i substituïm el fitxer per un de nou, les perdrem i les haurem de tornar a atorgar.

**Diskwatch**

[Diskwatch](https://github.com/matthart1983/diskwatch) és un monitor d'ús de disc per procés, que també mostra l'estat de salut dels discs via [*](SMART). Per a aquesta darrera funció necessita el paquet `smartmontools`, que és als repositoris:

```bash
sudo apt install smartmontools
```

La instal·lació és idèntica a la de Netwatch, canviant el nom i la versió:

```bash
DW_VERSION=0.7.1
cd "$(mktemp --directory)"
wget "https://github.com/matthart1983/diskwatch/releases/download/v${DW_VERSION}/diskwatch-linux-x86_64.tar.gz"
wget "https://github.com/matthart1983/diskwatch/releases/download/v${DW_VERSION}/SHA256SUMS"
sha256sum --ignore-missing --check SHA256SUMS
tar --extract --gzip --file=diskwatch-linux-x86_64.tar.gz diskwatch-linux-x86_64
mv diskwatch-linux-x86_64 ~/.local/bin/diskwatch
chmod +x ~/.local/bin/diskwatch
```

Per llegir les dades SMART dels discs, Diskwatch s'ha d'executar com a `root`. Però si provam `sudo diskwatch`, obtindrem un error `command not found`: per seguretat, `sudo` no usa el nostre `PATH`, sinó un de propi definit a `/etc/sudoers` (`secure_path`) que no inclou `~/.local/bin`. Li hem d'indicar el camí complet:

```bash
diskwatch                      # Sense dades SMART
sudo ~/.local/bin/diskwatch    # Amb dades SMART
```

**Syswatch**

[Syswatch](https://github.com/matthart1983/syswatch) és un monitor de sistema a l'estil de `top`, `htop` o `btop`: CPU, memòria, discs, processos i xarxa. No necessita privilegis addicionals i la seva instal·lació és anàloga a la de Diskwatch i Netwatch:

```bash
SW_VERSION=0.14.5
cd "$(mktemp --directory)"
wget "https://github.com/matthart1983/syswatch/releases/download/v${SW_VERSION}/syswatch-linux-x86_64.tar.gz"
wget "https://github.com/matthart1983/syswatch/releases/download/v${SW_VERSION}/SHA256SUMS"
sha256sum --ignore-missing --check SHA256SUMS
tar --extract --gzip --file=syswatch-linux-x86_64.tar.gz syswatch-linux-x86_64
mv syswatch-linux-x86_64 ~/.local/bin/syswatch
chmod +x ~/.local/bin/syswatch
syswatch
```

Haureu notat que les tres instal·lacions són pràcticament iguals. Quan repetim les mateixes passes una vegada i una altra canviant només un parell de valors, és el moment d'escriure un script. En veurem un exemple a l'apartat [Scripts de BASH](#scripts-de-bash).

## Formats universals

Tots els mètodes que hem vist fins ara són propis de Debian i Ubuntu. Un `.deb` no s'instal·la a Fedora ni a Arch Linux, i cada distribució empaqueta el programari a la seva manera. Per evitar que els desenvolupadors hagin de preparar un paquet per a cada distribució, han sorgit tres formats **universals**, que funcionen igual a qualsevol distribució perquè **duen dins totes les dependències** que necessiten.

El preu és que ocupen més espai, perquè no comparteixen biblioteques amb el sistema, i que les dependències que duen dins no s'actualitzen amb el sistema, sinó quan el desenvolupador publica una versió nova.

### Snap

Snap és el format desenvolupat per Canonical, l'empresa darrere d'Ubuntu. Els paquets (*snaps*) es descarreguen de la [Snap Store](https://snapcraft.io/store), s'executen aïllats de la resta del sistema i **s'actualitzen automàticament** en segon pla. Està pensat tant per a aplicacions d'escriptori com per a eines de terminal i serveis de servidor.

**Públic objectiu**: usuaris d'Ubuntu, que el duu instal·lat de sèrie i fins i tot instal·la alguns programes (com Firefox) com a snap. També administradors que volen una versió recent d'una eina amb actualitzacions automàtiques. A la resta de distribucions és poc habitual, en part perquè la botiga és centralitzada i la gestiona una sola empresa.

A Debian, primer l'hem d'instal·lar. A Ubuntu, tant d'escriptori com de servidor, ja ve de sèrie:

```bash
sudo apt install snapd
```

Cada snap és, per dins, una imatge de sistema de fitxers comprimida (SquashFS). La gestiona el servei `snapd`, que s'executa com a `root` i, per tant, la pot muntar directament amb el nucli. Ho podem veure amb `mount --types squashfs`, que mostra un muntatge a `/snap/<nom>/<revisió>` per a cada snap instal·lat[^7].

[^7]: El paquet `snapd` instal·la `fuse3` com a dependència, però només el fa servir com a alternativa quan el nucli no li permet muntar les imatges directament, cosa que passa, per exemple, si executam `snapd` dins un contenidor. Veurem què és FUSE a l'apartat d'AppImage.

Instal·lam `btop`, un monitor de sistema, i comprovam els snaps que tenim:

```bash
sudo snap install btop
snap list
btop
```

> `btop` també és als repositoris de Debian i Ubuntu. Si comparam `apt policy btop` amb `snap info btop` veurem que el snap sol oferir una versió més recent.

### Flatpak

Flatpak és un format orientat exclusivament a **aplicacions d'escriptori**. Les aplicacions s'executen dins un entorn aïllat (*sandbox*) i comparteixen entre elles uns **runtimes** comuns (conjunts de biblioteques), de manera que no cal descarregar les mateixes biblioteques per a cada aplicació. El repositori principal és [Flathub](https://flathub.org/), tot i que se'n poden afegir d'altres.

**Públic objectiu**: usuaris d'escriptori de qualsevol distribució que volen aplicacions gràfiques recents sense dependre del ritme de la seva distribució. No té sentit en servidors ni per a eines de terminal.

Ni Debian ni Ubuntu el duen de sèrie. L'instal·lam i afegim el repositori Flathub:

```bash
sudo apt install flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

> Si usau un escriptori KDE Plasma o GNOME, podeu instal·lar també el paquet `plasma-discover-backend-flatpak` o `gnome-software-plugin-flatpak`, perquè les aplicacions de Flathub apareguin a la botiga gràfica de programari. Després d'afegir Flathub per primera vegada convé tancar i tornar a obrir la sessió.

Instal·lam [Remmina](https://remmina.org/), un client d'escriptori remot que suporta RDP, VNC i SSH, i que ens serà molt útil quan facem feina amb servidors Windows:

```bash
flatpak install flathub org.remmina.Remmina
flatpak run org.remmina.Remmina
```

Les aplicacions Flatpak s'identifiquen amb un nom en format de domini invers (`org.remmina.Remmina`). Un cop instal·lada, també la trobarem al menú d'aplicacions de l'escriptori. Per actualitzar totes les aplicacions Flatpak:

```bash
flatpak update
```

### AppImage

AppImage és el format més senzill dels tres: l'aplicació i totes les seves dependències es distribueixen dins **un sol fitxer executable**. No hi ha instal·lació, no hi ha repositori i no cal `root`: descarregam el fitxer, li donam permís d'execució i l'executam. Per desinstal·lar-lo, l'esborram.

**Públic objectiu**: usuaris d'escriptori que volen provar o usar una aplicació sense tocar el sistema, o dur-la en un llapis USB d'un ordinador a un altre. El gran inconvenient és que, en general, **no s'actualitza tota sola** i no s'integra amb el menú de l'escriptori si no hi afegim res més.

Alguns exemples d'aplicacions d'escriptori útils per a un administrador que es distribueixen en aquest format:

- [KeePassXC](https://keepassxc.org/), un gestor de contrasenyes lliure.
- [draw.io Desktop](https://github.com/jgraph/drawio-desktop), una aplicació lliure per dibuixar diagrames de xarxa, d'arquitectura o de flux.
- [Obsidian](https://obsidian.md/), una aplicació per prendre notes en Markdown. És gratuïta però **privativa**: no en podem veure ni modificar el codi font. Ens recorda que el format en què es distribueix un programa no diu res de la seva llicència.

Igual que un snap, una AppImage duu dins una imatge SquashFS que s'ha de muntar en executar-la. Però un usuari normal no pot muntar sistemes de fitxers: això només ho pot fer `root`. Per això les AppImage usen **FUSE** (*Filesystem in Userspace*), un mecanisme del nucli que permet muntar sistemes de fitxers sense privilegis, a través de la comanda `fusermount3`.

Les AppImage actuals duen incorporat tot el codi de FUSE que necessiten i només requereixen aquesta comanda, que proporciona el paquet `fuse3`. A Debian, ho comprovam i, si cal, l'instal·lam (a Ubuntu ja ve de sèrie):

```bash
command -v fusermount3 || sudo apt install fuse3
```

> Les AppImage generades amb eines més antigues necessiten, a més, la biblioteca de la versió anterior de FUSE, `libfuse.so.2`. Si en executar-ne una obtenim l'error *dlopen(): error loading libfuse.so.2*, l'haurem d'instal·lar amb `sudo apt install libfuse2t64`. És la instrucció que trobarem a molts de tutorials. Si no podem usar FUSE de cap manera, per exemple dins un contenidor, podem executar l'aplicació amb l'opció `--appimage-extract-and-run`, que extreu la imatge a un directori temporal en lloc de muntar-la.

Instal·lam KeePassXC. Els repositoris de Debian 13 i d'Ubuntu 26.04 en tenen la versió 2.7.10, mentre que l'AppImage ens dona la darrera, la 2.8.0. A la [darrera versió](https://github.com/keepassxreboot/keepassxc/releases/latest) del projecte, cada fitxer va acompanyat d'un fitxer `.DIGEST`, amb la seva suma SHA-256, i d'un fitxer `.sig`, amb la seva signatura digital. Descarregam l'AppImage i el `.DIGEST`, i comprovam la suma:

```bash
KP_VERSION=2.8.0
cd ~/Downloads
wget "https://github.com/keepassxreboot/keepassxc/releases/download/${KP_VERSION}/KeePassXC-${KP_VERSION}-x86_64.AppImage"
wget "https://github.com/keepassxreboot/keepassxc/releases/download/${KP_VERSION}/KeePassXC-${KP_VERSION}-x86_64.AppImage.DIGEST"
sha256sum --check KeePassXC-${KP_VERSION}-x86_64.AppImage.DIGEST
```

Li donam permís d'execució, el movem a `~/.local/bin` amb un nom més curt i l'executam:

```bash
chmod +x KeePassXC-${KP_VERSION}-x86_64.AppImage
mv KeePassXC-${KP_VERSION}-x86_64.AppImage ~/.local/bin/keepassxc
keepassxc
```

> Les aplicacions d'escriptori basades en Electron, com draw.io o Obsidian, poden fallar en arrencar com a AppImage a Ubuntu per una restricció de seguretat d'AppArmor[^8]. En aquests casos, és més senzill instal·lar el `.deb` que també publiquen o la versió de Flathub.

[^8]: Des de la versió 24.04, Ubuntu restringeix els espais de noms d'usuari sense privilegis (*unprivileged user namespaces*), que és el mecanisme que usa Electron per aïllar els seus processos. Ubuntu inclou perfils d'AppArmor que ho permeten a algunes aplicacions instal·lades com a `.deb`, com Obsidian, però no a les AppImage. Executar l'aplicació amb l'opció `--no-sandbox` ho evita, però desactiva aquest aïllament.

### Quin format triar?

La següent taula pot ajudar-te a contestar aquesta pregunta:

|                     | Snap                           | Flatpak                        | AppImage                 |
| ------------------- | ------------------------------ | ------------------------------ | ------------------------ |
| Impulsat per        | Canonical                      | Comunitat (freedesktop.org)    | Comunitat                |
| Tipus de programari | Escriptori, terminal i serveis | Només escriptori               | Principalment escriptori |
| Repositori          | Snap Store (centralitzat)      | Flathub i altres               | Cap                      |
| Actualitzacions     | Automàtiques                   | `flatpak update`               | Manuals                  |
| Necessita `root`    | Sí                             | No (si s'instal·la per usuari) | No                       |
| Aïllament           | Sí                             | Sí                             | No                       |

Com a regla general, en un servidor ens quedarem amb els repositoris de la distribució i, si cal, amb els mètodes dels apartats anteriors. En un portàtil, Flatpak és una bona opció per a aplicacions gràfiques que no són als repositoris o que hi són massa antigues.

## Scripts de BASH

A l'apartat de binaris hem instal·lat tres eines repetint gairebé les mateixes comandes, i quan en surti una versió nova les haurem de tornar a escriure totes. Quan una tasca es repeteix així, el pas natural és automatitzar-la amb un **script**: un fitxer de text amb les comandes que executaria la shell una darrera l'altra.

L'script següent, `install-watch.sh`, instal·la o actualitza qualsevol de les tres eines. Rep com a primer paràmetre el nom de l'eina i, com a segon paràmetre opcional, la versió. Si no n'hi indicam cap, instal·la la darrera, aprofitant la URL `releases/latest/download/` de GitHub:

```bash
./install-watch.sh syswatch
./install-watch.sh diskwatch 0.7.1
```

> Aquest script suposa que coneixes els fonaments de BASH (variables, condicionals, bucles i funcions). Si no és el cas, no et preocupis: el pots usar igualment i entendre'l més endavant al curs.

```bash
#!/usr/bin/env bash
#
# Instal·la o actualitza Netwatch, Diskwatch o Syswatch a ~/.local/bin.
#
# Ús: install-watch.sh <eina> [versió]
#   eina:   netwatch, diskwatch o syswatch
#   versió: número de versió (e.g. 0.40.0) o "latest" (per defecte)

set -euo pipefail

readonly INSTALL_DIR="${HOME}/.local/bin"
readonly GITHUB_USER="matthart1983"

usage() {
    echo "Ús: $(basename "$0") <netwatch|diskwatch|syswatch> [versió|latest]" >&2
    exit 1
}

# Comprovam els paràmetres
if [[ $# -lt 1 ]]; then
    usage
fi

TOOL="$1"
VERSION="${2:-latest}"

case "${TOOL}" in
    netwatch|diskwatch|syswatch) ;;
    *) usage ;;
esac

# Comprovam l'arquitectura i les dependències
if [[ "$(uname --machine)" != "x86_64" ]]; then
    echo "Error: aquest script només funciona en sistemes x86_64." >&2
    exit 1
fi

for cmd in wget sha256sum tar; do
    if ! command -v "${cmd}" > /dev/null; then
        echo "Error: falta la comanda ${cmd}." >&2
        exit 1
    fi
done

# Calculam les URL de descàrrega
ASSET="${TOOL}-linux-x86_64"
REPO_URL="https://github.com/${GITHUB_USER}/${TOOL}"

if [[ "${VERSION}" == "latest" ]]; then
    BASE_URL="${REPO_URL}/releases/latest/download"
else
    BASE_URL="${REPO_URL}/releases/download/v${VERSION}"
fi

# Feim feina en un directori temporal que s'esborra en acabar
TMP_DIR="$(mktemp --directory)"
trap 'rm -rf "${TMP_DIR}"' EXIT
cd "${TMP_DIR}"

echo "Descarregant ${TOOL} (versió: ${VERSION})..."
wget --quiet "${BASE_URL}/${ASSET}.tar.gz"
wget --quiet "${BASE_URL}/SHA256SUMS"

echo "Verificant la suma de comprovació..."
sha256sum --ignore-missing --check SHA256SUMS

echo "Instal·lant a ${INSTALL_DIR}/${TOOL}..."
tar --extract --gzip --file="${ASSET}.tar.gz" "${ASSET}"
mkdir --parents "${INSTALL_DIR}"
mv "${ASSET}" "${INSTALL_DIR}/${TOOL}"
chmod +x "${INSTALL_DIR}/${TOOL}"

# Passes específiques de cada eina
case "${TOOL}" in
    netwatch)
        echo "Atorgant capacitats de captura de xarxa (cal sudo)..."
        sudo setcap 'cap_net_raw,cap_bpf,cap_perfmon+eip' "${INSTALL_DIR}/${TOOL}"
        ;;
    diskwatch)
        if ! dpkg --status smartmontools > /dev/null 2>&1; then
            echo "Instal·lant smartmontools (cal sudo)..."
            sudo apt-get install --yes smartmontools
        fi
        ;;
esac

echo "Fet! Executa ${TOOL} per començar."
```

Hi trobam les mateixes passes que fèiem a mà, més unes quantes comprovacions que fan l'script més robust:

- `set -euo pipefail` fa que l'script sigui més segur. Per defecte, BASH continua executant la línia següent encara que una comanda hagi fallat. Amb aquesta línia:
  - `-e` atura l'script si una comanda falla.
  - `-u` l'atura si usam una variable que no existeix (per exemple, per un error en escriure'n el nom).
  - `-o pipefail` fa que una canonada falli si falla qualsevol de les comandes que la formen, no només la darrera.
- Abans de descarregar res, comprova els paràmetres, l'arquitectura del sistema i que les comandes que necessita estiguin instal·lades.
- Fa feina en un directori temporal que `trap` esborra en acabar, tant si tot ha anat bé com si no.
- Usa `apt-get` en comptes d'`apt`, tal com hem explicat al primer apartat, perquè és dins un script.

Per usar-lo, el desam a `~/Projects/scripts-bash/install-watch.sh`, li donam permís d'execució i l'executam indicant el camí:

```bash
chmod +x install-watch.sh
./install-watch.sh netwatch
```

Fixau-vos que l'script serveix tant per instal·lar com per **actualitzar**: si l'executam quan l'eina ja està instal·lada, substitueix el binari per la versió nova i, en el cas de Netwatch, torna a atorgar les capacitats que es perden en substituir el fitxer.

## Exercici

**Instal·lació d'eines de sistemes**

Objectiu: triar, per a cada aplicació, el mètode d'instal·lació més adient dels que hem vist a l'article, i justificar-ne l'elecció.

Instal·la les aplicacions següents, bé al teu portàtil, bé en un servidor al qual accedeixis per SSH.

| Aplicació                                                 | Què és                                                                       |
| --------------------------------------------------------- | ---------------------------------------------------------------------------- |
| [duf](https://github.com/muesli/duf)                      | Alternativa a `df` que mostra l'ocupació dels sistemes de fitxers en taules  |
| [bottom](https://github.com/ClementTsang/bottom)          | Monitor de sistema amb gràfiques de CPU, memòria, xarxa, disc i temperatures |
| [Docker Engine](https://docs.docker.com/engine/)          | Plataforma de contenidors de codi obert de referència                        |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Interfície de terminal per gestionar contenidors, imatges i volums de Docker |
| [OpenCode](https://opencode.ai/)                          | Agent de programació amb IA per a la terminal                                |
| [Hugo](https://gohugo.io/)                                | Generador de llocs web estàtics, versió *extended*                           |

Per a cada aplicació:

1. Comprova si és als repositoris de la distribució i amb quina versió, i quina és la darrera versió publicada pel projecte.
2. Tria el mètode d'instal·lació i justifica'l en una o dues frases.
3. Verifica la integritat del que descarreguis, sempre que el projecte ho permeti.
4. Comprova que funciona i anota la versió instal·lada.
5. Explica com l'actualitzaràs quan surti una versió nova.

> Pistes:
>
> - La documentació oficial de cada projecte sol indicar quins mètodes d'instal·lació recomana.
> - El nom d'un paquet no sempre coincideix amb el nom de la comanda que instal·la. `dpkg --listfiles` t'ho pot dir.
> - Abans d'executar un script instal·lador, llegeix-lo: on instal·la el binari, si modifica fitxers de configuració i si verifica el que descarrega.
> - lazydocker necessita Docker. Si en executar-lo obtens un error de permisos amb el *socket* de Docker, mira a quin usuari i grup pertany `/var/run/docker.sock`.

{{< details summary="Resposta" >}}

No hi ha una única resposta correcta: el que importa és que la justificació sigui coherent amb el que hem vist a l'article. Aquesta és una proposta:

| Aplicació     | Mètode proposat                           | Actualització               |
| ------------- | ----------------------------------------- | --------------------------- |
| duf           | Repositoris o paquet `.deb` de GitHub     | `apt full-upgrade` o manual |
| bottom        | Paquet `.deb` de GitHub                   | Manual, repetint el procés  |
| Docker Engine | Repositori extern de Docker, clau i fonts | `apt full-upgrade`          |
| lazydocker    | Binari dins un `.tar.gz` a `~/.local/bin` | Manual, repetint el procés  |
| OpenCode      | Script instal·lador, després de llegir-lo | Tornant a executar l'script |
| Hugo          | Paquet `.deb` o `.tar.gz` de GitHub       | Manual, repetint el procés  |

**duf.** Els repositoris de Debian 13 tenen la versió 0.8.1, mentre que a GitHub hi ha la 0.9.1. Si la versió del repositori ens basta, és la via preferent: `sudo apt install duf`. Si volem la darrera, el projecte publica un `.deb` i un fitxer `checksums.txt`:

```bash
DUF_VERSION=0.9.1
cd ~/Downloads
wget "https://github.com/muesli/duf/releases/download/v${DUF_VERSION}/duf_${DUF_VERSION}_linux_amd64.deb"
wget "https://github.com/muesli/duf/releases/download/v${DUF_VERSION}/checksums.txt"
sha256sum --ignore-missing --check checksums.txt
sudo apt install ./duf_${DUF_VERSION}_linux_amd64.deb
```

A Ubuntu 26.04, en canvi, els repositoris ja tenen la 0.9.1. Si hi instal·lam el `.deb` de GitHub, el proper `apt full-upgrade` el substituirà pel paquet del repositori: el `.deb` de GitHub té la versió `0.9.1` i el d'Ubuntu, la `0.9.1-1`, on el `-1` és la **revisió** del paquet i fa que `apt` el consideri més nou.

**bottom.** Els repositoris el tenen, però amb un nom diferent, `btm`, i una versió molt més antiga (0.10.2 a Debian 13 i 0.12.3 a Ubuntu 26.04, enfront de la 0.15.0 de GitHub). El projecte no publica cap fitxer de sumes, així que comparam la suma del `.deb` amb la que mostra GitHub. La comanda instal·lada és `btm`. A més, les etiquetes de les versions de bottom no duen el prefix `v`:

```bash
BTM_VERSION=0.15.0
cd ~/Downloads
wget "https://github.com/ClementTsang/bottom/releases/download/${BTM_VERSION}/bottom_${BTM_VERSION}-1_amd64.deb"
echo "<suma-sha256-de-github>  bottom_${BTM_VERSION}-1_amd64.deb" | sha256sum --check
sudo apt install ./bottom_${BTM_VERSION}-1_amd64.deb
dpkg --listfiles bottom | grep bin/
```

**Docker Engine.** Els repositoris de Debian i Ubuntu inclouen el paquet `docker.io`, però la documentació oficial, tant per a [Debian](https://docs.docker.com/engine/install/debian/) com per a [Ubuntu](https://docs.docker.com/engine/install/ubuntu/), recomana usar el repositori de Docker, que segueix el mateix procediment que Brave: clau a `/etc/apt/keyrings/docker.asc` i fitxer de fonts a `/etc/apt/sources.list.d/docker.sources`. La signatura del repositori garanteix l'autenticitat dels paquets i rebrem les actualitzacions amb la resta del sistema. Verificam la instal·lació amb `sudo docker run hello-world`.

**lazydocker.** No és als repositoris. El projecte publica un `.tar.gz` i un fitxer `checksums.txt`, igual que les eines de l'apartat de binaris:

```bash
LD_VERSION=0.25.2
cd "$(mktemp --directory)"
wget "https://github.com/jesseduffield/lazydocker/releases/download/v${LD_VERSION}/lazydocker_${LD_VERSION}_Linux_x86_64.tar.gz"
wget "https://github.com/jesseduffield/lazydocker/releases/download/v${LD_VERSION}/checksums.txt"
sha256sum --ignore-missing --check checksums.txt
tar --extract --gzip --file=lazydocker_${LD_VERSION}_Linux_x86_64.tar.gz \
  --directory="$HOME/.local/bin" lazydocker
```

L'error de permisos apareix perquè el *socket* de Docker pertany a `root` i al grup `docker`. Podem executar `sudo ~/.local/bin/lazydocker` o afegir el nostre usuari al grup amb `sudo usermod --append --groups docker $USER` i tornar a iniciar sessió, tenint en compte que pertànyer al grup `docker` equival a tenir privilegis de `root`.

**OpenCode.** No és als repositoris i el projecte proposa un script instal·lador. Si el llegim abans d'executar-lo, veurem que instal·la el binari a `~/.opencode/bin`, que afegeix aquest directori al `PATH` escrivint una línia a `~/.bashrc` (tret que li passem `--no-modify-path`) i que, a diferència del de Portop, **no verifica cap suma de comprovació** del que descarrega:

```bash
curl --fail --silent --show-error --location --output /tmp/opencode-install.sh \
  https://opencode.ai/v2/install
less /tmp/opencode-install.sh
bash /tmp/opencode-install.sh
```

**Hugo.** Els repositoris de Debian 13 tenen la versió 0.131.0 (i els d'Ubuntu 26.04, la 0.154.5), mentre que la darrera és la 0.169.0. Com que Hugo s'actualitza molt sovint i els temes solen necessitar versions recents, val la pena instal·lar-lo des de GitHub. El projecte publica tant un `.deb` com un `.tar.gz` de la versió *extended*, i un fitxer de sumes amb el número de versió al nom:

```bash
HUGO_VERSION=0.169.0
cd "$(mktemp --directory)"
wget "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb"
wget "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_checksums.txt"
sha256sum --ignore-missing --check hugo_${HUGO_VERSION}_checksums.txt
sudo apt install ./hugo_extended_${HUGO_VERSION}_linux-amd64.deb
hugo version
```

Una bona ampliació seria adaptar l'script `install-watch.sh` per instal·lar lazydocker o Hugo. Tenguis en compte, però, que els noms dels seus fitxers inclouen el número de versió, així que no podem usar la URL `releases/latest/download/`.

{{< /details >}}

## Conclusió

Hem vist que, a Debian i Ubuntu, hi ha moltes maneres d'afegir programari al sistema, i que no totes són equivalents. Com a regla general, seguirem aquest ordre de preferència:

1. **Repositoris de la distribució**, sempre que el programari hi sigui i la versió ens basti.
2. **Repositori del fabricant**, configurat per un paquet o per nosaltres, quan necessitam una versió més recent o el programari no és a la distribució. Rebrem actualitzacions amb la resta del sistema.
3. **Paquets DEB, binaris o scripts instal·ladors**, quan no hi ha cap repositori. Ens tocarà a nosaltres estar atents a les versions noves, i un script ens farà la feina molt més fàcil.
4. **Flatpak, Snap o AppImage**, sobretot per a aplicacions d'escriptori als nostres portàtils.

Sigui quin sigui el mètode, la pregunta que s'ha de fer sempre un administrador de sistemes és **en qui estic confiant**. Quan instal·lam un paquet de Debian, confiam en l'equip de Debian. Quan afegim un repositori extern, confiam en aquell fabricant per a totes les actualitzacions futures. Quan executam `curl | sh`, confiam en un script que potser no hem llegit. Verificar les sumes de comprovació, llegir els scripts abans d'executar-los i preferir `~/.local/bin` a `sudo` sempre que es pugui són hàbits que convé adquirir des del primer dia.
