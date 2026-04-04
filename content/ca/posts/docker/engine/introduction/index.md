---
title: "Introducció a Docker"
date: 2026-03-24
lastmod: 2026-03-24
description: "Context històric, arquitectura de Docker, comparativa amb màquines virtuals i altres tecnologies de contenidors"
summary: "Context històric, arquitectura de Docker, comparativa amb màquines virtuals i altres tecnologies de contenidors"
categories: ["teaching"]
tags: ["docker", "engine", "containers"]
series: ["Docker Engine"]
series_order: 1
weight: 10
slug: introduccio
---

Per entendre per què Docker va revolucionar el desplegament de programari, cal fer un salt enrere i comprendre com es desplegaven les aplicacions abans de la contenització.

**L'era dels servidors físics**

Durant dècades, desplegar una aplicació significava instal·lar-la directament sobre un servidor físic. Cada servidor era una màquina única, configurada manualment per un administrador de sistemes que instal·lava el sistema operatiu, les biblioteques necessàries, les dependències de l'aplicació i, finalment, l'aplicació mateixa. Aquest procés podia tardar dies o setmanes, i cada servidor es convertia en el que avui anomenaríem una *mascota*: un sistema únic, amb la seva pròpia personalitat i peculiaritats, que calia cuidar i mantenir amb atenció.

El problema més greu d'aquest model era la *inconsistència entre entorns*. Un desenvolupador creava una aplicació al seu ordinador de sobretaula (l'entorn de desenvolupament), la provava en un servidor de proves i, finalment, la desplegava al servidor de producció. Però cada un d'aquests entorns era diferent: versions diferents del sistema operatiu, versions diferents de les biblioteques, configuracions diferents del sistema. El resultat era el famós problema de *"funciona a la meva màquina"*: una aplicació que funcionava perfectament a l'ordinador del desenvolupador podia fallar misteriosament en producció.

Les solucions de l'època eren rudimentàries i no hi havia els mateixos recursos dels quals disposem avui en dia. Els equips creaven *documentació exhaustiva* que detallava pas a pas com configurar cada servidor. Però la documentació s'anava quedant obsoleta, els passos es saltaven o s'executaven en ordre incorrecte, i les diferències subtils entre entorns s'acumulaven. Alguns equips desenvolupaven *scripts de desplegament* en Bash o Perl que intentaven automatitzar el procés, però aquests scripts eren difícils de mantenir i sovint específics per a cada aplicació.

**Les eines de gestió de configuració**

Als anys 2000, van aparèixer les primeres *eines de gestió de configuració* (CFEngine el 1993, Puppet el 2005, Chef el 2009, Ansible el 2012) que prometien resoldre aquests problemes. Aquestes eines permetien descriure l'estat desitjat d'un servidor en fitxers de configuració declaratius i després aplicar automàticament els canvis necessaris per assolir aquest estat.

Puppet i Chef van representar un avenç significatiu: per primera vegada, la configuració d'un servidor podia ser versionada, revisada i aplicada de manera repetible. Tanmateix, aquestes eines treballaven *modificant* servidors existents, no creant-ne de nous. Si un servidor havia acumulat canvis manuals al llarg del temps, l'eina de configuració podia trobar-se amb conflictes inesperats.

**L'era de la virtualització**

La *virtualització* va emergir com una solució parcial al problema de la inconsistència. Amb eines com VMware (1998), Xen (2003) i KVM (2006), els equips podien crear *màquines virtuals* que encapsulaven tot un sistema operatiu amb la seva configuració. En teoria, podies crear una VM amb la configuració exacta de producció i distribuir-la als desenvolupadors perquè fessin feina en un entorn idèntic.

Però les VMs tenien els seus propis problemes. Cada màquina virtual requeria un *sistema operatiu complet* i la seva arrencada podia tardar uns minuts, fent impossible l'escalat ràpid davant pics de demanda. I tot i que la virtualització facilitava crear entorns idèntics, *la gestió de les imatges de VM* (creació, actualització, distribució) era feixuga i requeria eines addicionals.

El problema fonamental persistia: el desplegament de programari continuava sent un procés manual, lent i propens a errors. Els equips dedicaven una quantitat desproporcionada de temps a problemes d'infraestructura en comptes de centrar-se en el desenvolupament de funcionalitats. Calia un canvi de paradigma.

## Fonaments i evolució

La tecnologia de contenidors no va aparèixer del no-res. Es va construir sobre dècades de desenvolupament en aïllament de processos i gestió de recursos.

| Era                        | Tecnologia  | Any       | Descripció                           | Característiques clau                                            |
|----------------------------|-------------|-----------|--------------------------------------|------------------------------------------------------------------|
| Fonaments inicials         | chroot      | 1979      | Aïllament del sistema de fitxers     | Restrir accés d'un procés a un arbre de directoris específic     |
| Precursor dels contenidors | BSD Jails   | 2000      | Primera contenització generalitzada  | Aïllament de processos, separació del sistema de fitxers         |
| Fonaments Linux            | Namespaces  | 2002–2013 | Mecanismes d'aïllament per a Linux   | Aïllament de processos, xarxa, usuaris i altres recursos         |
| Fonaments Linux            | cgroups     | 2007      | Gestió i límits de recursos          | CPU, memòria, E/S de disc, comptabilitat i limitació de recursos |
| Contenidors Linux          | LXC / LXD   | 2008+     | Contenidors de sistema               | Entorns aïllats similars a VMs usant cgroups i namespaces        |
| Revolució dels contenidors | Docker      | 2013      | Contenidors d'aplicació i ecosistema | Empaquetament, distribució i execució simplificats               |
| Orquestració               | Kubernetes  | 2014      | Orquestració de contenidors a escala | Desplegament, escalat i gestió automatitzats de contenidors      |

### BSD Jails

Les jails de FreeBSD, introduïdes l'any 2000, van ser la primera tecnologia de contenització generalitzada. Proporcionaven aïllament de processos i sistema de fitxers creant entorns separats que compartien el nucli de l'amfitrió però apareixien com a sistemes complets per als processos que s'executaven dins. Cada jail tenia la seva pròpia jerarquia de sistema de fitxers, espai d'usuari i pila de xarxa, fent impossible que els processos d'una jail interferissin amb els d'una altra. Les jails van ser dissenyades principalment per a la seguretat: els proveïdors d'allotjament les usaven per donar als clients accés root als seus propis entorns sense comprometre el sistema amfitrió.

### Fonaments a Linux

Linux va prendre un enfocament diferent, construint capacitats de contenització a través de diverses funcionalitats del nucli desenvolupades al llarg de molts anys. La crida al sistema `chroot`, disponible des de 1979, proporcionava aïllament bàsic del sistema de fitxers canviant el directori arrel aparent per a un procés. Tanmateix, `chroot` era principalment una eina de seguretat i no proporcionava aïllament complet: els processos encara podien veure altres processos del sistema i accedir a recursos compartits.

Els grups de control (*cgroups*), introduïts el 2007, van afegir capacitats de gestió de recursos. Els cgroups permetien als administradors limitar CPU, memòria, E/S de disc i ample de banda de xarxa per a grups de processos. Això era crucial per a entorns multi-inquilí on calia evitar que una aplicació consumís tots els recursos del sistema. Els *namespaces* de Linux, desenvolupats entre 2002 i 2013, van proporcionar aïllament de processos, aïllament de xarxa, mapatge d'IDs d'usuari i altres funcionalitats d'aïllament. Juntes, aquestes tecnologies van crear els fonaments dels contenidors Linux moderns.

### Contenidors de sistema

Linux Containers (LXC), llançat el 2008, va ser la primera solució de contenització completa per a Linux, combinant *cgroups*, *namespaces* i `chroot` en un paquet fàcil d'usar. Els contenidors LXC eren *contenidors de sistema*: es comportaven com a màquines virtuals lleugeres, amb el seu propi sistema d'inicialització, múltiples processos i emmagatzematge persistent. Els usuaris podien instal·lar programari, modificar configuracions i tractar els contenidors com si fossin màquines separades.

LXD, desenvolupat per Canonical, va modernitzar LXC amb una API REST, millor xarxa i eines de gestió millorades. Els contenidors de sistema excel·leixen en escenaris on es necessita funcionalitat similar a VM amb eficiència de contenidor: entorns de desenvolupament, executors de CI/CD o migració d'aplicacions legacy. Tanmateix, conserven gran part de la complexitat de l'administració de sistemes tradicional, requerint que els usuaris gestionin actualitzacions, serveis i configuracions dins de cada contenidor.

### Contenidors d'aplicació

Docker, llançat el 2013, va canviar fonamentalment la manera de pensar sobre els contenidors. En lloc de contenidors de sistema que replicaven màquines senceres, Docker va popularitzar els *contenidors d'aplicació*: paquets lleugers que contenien només l'aplicació i les seves dependències. Docker va introduir el concepte d'imatges de contenidor immutables construïdes a partir de Dockerfiles declaratius, fent les aplicacions veritablement portables i reproduïbles.

La innovació clau de Docker va ser tractar els contenidors com a *bestiar*, no com a *mascotes*. Els sistemes tradicionals eren mascotes: únics, mantinguts amb cura i difícils de substituir. Els contenidors Docker eren bestiar: idèntics, reemplaçables i efímers. Aquest canvi va permetre nous patrons de desplegament com les actualitzacions progressives, els desplegaments blue-green i l'autoescalat que es convertirien en fonamentals per a les arquitectures cloud-native modernes.

### Orquestració

A mesura que l'adopció de contenidors va créixer, les organitzacions van necessitar eines per gestionar centenars o milers de contenidors a través de múltiples amfitrions. Van emergir dues solucions principals: Docker Swarm i Kubernetes.

**Docker Swarm**, introduït el 2014 com a part de Docker Engine, va ser la primera resposta de Docker a aquesta necessitat. Swarm permetia convertir un grup de màquines Docker en un clúster unificat, on els contenidors es distribuïen automàticament entre els nodes. El seu disseny prioritzava la simplicitat: els usuaris que ja coneixien Docker podien adoptar Swarm amb un esforç mínim, ja que les comandes i fitxers de configuració eren molt similars. Swarm va introduir conceptes com els *serveis* (definicions declaratives d'aplicacions amb rèpliques), les *xarxes overlay* (comunicació entre contenidors en diferents nodes) i els *secrets* (gestió segura de credencials).

**Kubernetes**, llançat per Google el 2014 (basat en el seu sistema intern Borg), va prendre un enfocament més ambiciós. Kubernetes va abstraure els amfitrions individuals, presentant un clúster com un únic conjunt de recursos on els contenidors podien ser programats segons els requisits de recursos i restriccions. Va introduir conceptes sofisticats com els *Pods* (grups de contenidors co-localitzats), els *Deployments* (gestió declarativa d'aplicacions amb actualitzacions progressives), els *Services* (descobriment i balanceig de càrrega) i els *ConfigMaps* (configuració externalitzada).

Amb el temps, Kubernetes va guanyar adopció en entorns empresarials gràcies al suport dels principals proveïdors de núvol i un ecosistema d'extensions molt extens. Tanmateix, aquest poder venia amb complexitat: Kubernetes té una corba d'aprenentatge pronunciada i requereix experiència operativa significativa. Docker Swarm, per contra, va mantenir el seu enfocament en la simplicitat, convertint-se en l'opció preferida per a equips que necessitaven orquestració sense la sobrecàrrega operativa de Kubernetes.

## Comparativa tecnològica

Diferències tècniques clau:

* Compartició del nucli vs. nuclis separats.
* Capes d'imatge vs. sistemes de fitxers complets.
* Immutabilitat vs. sistemes persistents.

| Tecnologia | Nivell d'aïllament          | Sobrecàrrega de recursos | Cas d'ús                            | Corba d'aprenentatge |
|:----------:|-----------------------------|:------------------------:|-------------------------------------|:--------------------:|
| VMs        | Sistema operatiu complet    | Alta                     | Aplicacions legacy, diferents SOs   | Mitjana              |
| BSD Jails  | Procés + sistema de fitxers | Baixa                    | Sistemes orientats a seguretat      | Alta                 |
| LXC/LXD    | Contenidors de sistema      | Baixa-Mitjana            | Substitució de VMs, desenvolupament | Mitjana              |
| Docker     | Contenidors d'aplicació     | Molt baixa               | Microserveis, CI/CD                 | Baixa                |
| Kubernetes | Capa d'orquestració         | Mitjana                  | Escalat en producció                | Alta                 |

### Màquines virtuals

Les màquines virtuals proporcionen aïllament complet executant instàncies de sistema operatiu separades sobre maquinari virtualitzat. Cada VM té el seu propi nucli, controladors i biblioteques del sistema, fent-les ideals per executar aplicacions amb diferents requisits de SO o aplicacions legacy que requereixen configuracions de sistema específiques. Les VMs excel·leixen en escenaris sensibles a la seguretat perquè l'hipervisor proporciona límits d'aïllament forts: una VM compromesa no pot accedir directament al sistema amfitrió o altres VMs.

Tanmateix, aquest aïllament complet té un cost. Les VMs tenen una sobrecàrrega de recursos significativa: cada VM requereix memòria per al seu SO convidat (típicament 512 MB–2 GB mínim), emmagatzematge per als fitxers del SO (diversos GB) i cicles de CPU per a les operacions del SO. Iniciar una VM requereix temps (30 segons a diversos minuts) ja que tot el SO ha d'arrencar. Això fa les VMs inadequades per a l'escalat ràpid o arquitectures de microserveis on podries necessitar iniciar centenars d'instàncies d'aplicació.

### BSD Jails

Les BSD Jails prioritzen la seguretat i l'estabilitat, fent-les populars en entorns d'allotjament i organitzacions conscients de la seguretat. Les jails proporcionen un fort aïllament de processos: els processos en una jail no poden veure ni interactuar amb processos d'altres jails o del sistema amfitrió. L'aïllament del sistema de fitxers és complet i les jails poden tenir les seves pròpies interfícies de xarxa i adreces IP. La implementació madura de FreeBSD significa que les jails són sòlides i provades en entorns de producció.

Les principals limitacions de les BSD Jails són relacionades amb l'ecosistema més que tècniques. Estan lligades a FreeBSD, que té un ecosistema més petit que Linux per a aplicacions modernes. No hi ha un equivalent a Docker Hub per compartir configuracions de jail i les eines són més d'estil Unix tradicional en comptes de les eines modernes i amigables per a desenvolupadors que van fer Docker popular.

### LXC/LXD

Els contenidors LXC/LXD troben un equilibri entre funcionalitat de VM i eficiència de contenidor. Proporcionen funcionalitat propera a VM (pots instal·lar programari, executar múltiples serveis i persistir dades) mentre comparteixen el nucli de l'amfitrió per a una millor eficiència de recursos. La interfície de gestió moderna de LXD fa les operacions directes, amb funcionalitats com migració en viu, instantànies i límits de recursos que rivalitzen amb les plataformes de virtualització tradicionals.

Els contenidors de sistema excel·leixen quan necessites executar aplicacions que esperen un entorn Linux tradicional: aplicacions legacy, entorns de desenvolupament que necessiten coincidir amb producció de prop, o escenaris on necessites empaquetar múltiples serveis relacionats junts. Tanmateix, requereixen més sobrecàrrega operativa que els contenidors d'aplicació perquè has de mantenir el programari i les configuracions dins de cada contenidor, similar a gestionar màquines virtuals.

### Docker

Docker va tenir èxit perquè es va optimitzar per a l'experiència del desenvolupador i la portabilitat de l'aplicació. Els Dockerfiles proporcionen una manera simple i declarativa de definir entorns d'aplicació i el sistema de fitxers per capes fa les construccions eficients i les imatges compartibles. L'enfocament de Docker d'empaquetar només l'aplicació i les seves dependències d'execució resulta en imatges que típicament són entre un i dos ordres de magnitud més petites que les imatges de VM i s'inicien en segons en lloc de minuts.

Els contenidors Docker són efímers i immutables: estan dissenyats per ser substituïts en lloc de modificats. Aquest enfocament permet patrons de desplegament potents com els desplegaments blue-green i fa les aplicacions més predictibles i fàcils de depurar. Tanmateix, aquesta immutabilitat pot ser desafiant per a aplicacions dissenyades amb models de desplegament tradicionals i el model de seguretat de Docker (compartir el nucli de l'amfitrió) requereix consideració acurada en entorns multi-inquilí.

### Docker Swarm

Docker Swarm és el mode d'orquestració integrat a Docker Engine. Permet crear un clúster de nodes Docker que treballen conjuntament per executar serveis distribuïts. Swarm destaca per la seva corba d'aprenentatge suau: els fitxers `docker-compose.yml` es poden desplegar directament com a stacks, i les comandes (`docker service`, `docker stack`) segueixen la mateixa filosofia que la resta de Docker.

Swarm proporciona funcionalitats essencials d'orquestració: desplegament declaratiu de serveis, escalat horitzontal, actualitzacions progressives (*rolling updates*) amb rollback automàtic, descobriment de serveis integrat, balanceig de càrrega, i gestió de secrets i configuracions. Per a moltes aplicacions, aquestes funcionalitats són suficients sense la complexitat addicional de Kubernetes.

Les limitacions de Swarm apareixen en escenaris d'alta complexitat: no té l'ecosistema d'operadors i extensions de Kubernetes, l'autoescalat basat en mètriques requereix eines externes i algunes funcionalitats avançades (com els *service meshes*) no estan tan madures. Tanmateix, per a equips que prioritzen la simplicitat operativa sobre les funcionalitats avançades, Swarm continua sent una opció excel·lent.

### Kubernetes

Kubernetes proporciona orquestració de contenidors amb funcionalitats avançades com escalat automàtic basat en mètriques, actualitzacions progressives, descobriment de serveis i portabilitat multi-núvol. Abstreu la complexitat de la infraestructura, permetent als desenvolupadors declarar l'estat desitjat de l'aplicació mentre Kubernetes gestiona els detalls d'implementació. Funcionalitats com l'Horizontal Pod Autoscaler ajusten automàticament les instàncies d'aplicació basant-se en CPU, memòria o mètriques personalitzades i les capacitats de *service mesh* (Istio, Linkerd) permeten gestió de trànsit sofisticada i observabilitat.

Tanmateix, la complexitat de Kubernetes és significativa. Un clúster Kubernetes bàsic requereix entendre dotzenes de tipus de recursos (Pods, Services, Deployments, ConfigMaps, Secrets, Ingress, etc.) i les seves interaccions. Operar Kubernetes requereix experiència en xarxes, emmagatzematge, seguretat i sistemes distribuïts. Moltes organitzacions subestimen la sobrecàrrega operativa i es troben dedicant més temps a gestionar Kubernetes que a desenvolupar aplicacions.

La decisió entre Swarm i Kubernetes no hauria de basar-se en què és *"millor"*, sinó en què s'adequa als requisits i capacitats de l'equip. Swarm és suficient per a la majoria d'aplicacions web, APIs i serveis empresarials de mida mitjana. Kubernetes brilla en escenaris amb centenars de microserveis, requisits d'autoescalat agressiu, o necessitat d'integració amb un ecosistema cloud-native extens.

## Docker guanyador

Docker va guanyar no per ser tècnicament superior, sinó per oferir la millor experiència als desenvolupadors:

- Dockerfile simple i comandes intuïtives són la base d'una bona experiència del desenvolupador.
- Docker Hub va fer que compartir fos trivial a través del seu ecosistema de registres.
- Emmagatzematge i cache eficients gràcies al sistema de fitxers per capes.
- Docker Compose, Docker Swarm i integració amb IDEs formen un sòlid ecosistema d'eines.
- Docker va aprofitar el moment de la indústria a través del moviment de microserveis i la cultura DevOps.
- Lloc adequat, moment adequat i missatge adequat com a bases del màrqueting.

**L'experiència del desenvolupador**

L'èxit de Docker va derivar del seu enfocament en l'experiència del desenvolupador més que en l'administració de sistemes. Mentre que LXC requeria fitxers de configuració XML complexos i eines de línia de comandes que semblaven utilitats Unix tradicionals, Docker va introduir el Dockerfile: un format simple i llegible per humans que els desenvolupadors podien entendre i versionar juntament amb el codi de la seva aplicació. Les comandes `docker build`, `docker run` i `docker push` van proporcionar un flux de feina intuïtiu que coincidia amb com els desenvolupadors pensaven sobre el cicle de vida de l'aplicació.

Docker també va eliminar el problema de *"funciona a la meva màquina"* de manera definitiva. Una imatge Docker construïda al portàtil d'un desenvolupador s'executaria de manera idèntica a qualsevol sistema amb Docker instal·lat. Aquesta garantia va ser revolucionària per a equips de desenvolupament que havien passat anys lluitant amb errors específics de l'entorn i procediments de desplegament complexos. La capacitat de compartir entorns complets a través d'imatges Docker va significar que incorporar nous desenvolupadors es va convertir en tan simple com executar `docker compose up`.

**Reutilitzar i compartir**

Docker Hub va crear una cultura de compartir que no existia amb les tecnologies de contenidors anteriors. Els desenvolupadors podien descarregar imatges oficials per a bases de dades, servidors web i entorns d'execució de llenguatges de programació amb una sola comanda. Aquest efecte d'ecosistema va accelerar l'adopció de Docker: en lloc de construir tot des de zero, els desenvolupadors podien construir sobre fonaments provats. El concepte d'imatges base va significar que les actualitzacions de seguretat i millores podien ser compartides a través de tot l'ecosistema.

El sistema de fitxers per capes va ser crucial per a aquest model de compartir. Les capes comunes (com les imatges base del SO o els entorns d'execució) eren compartides entre contenidors, fent l'emmagatzematge eficient i les descàrregues ràpides. Quan descarregaves una nova imatge d'aplicació Python, potser només necessitaves descarregar la capa de l'aplicació si ja tenies la capa de l'entorn d'execució Python a la cache local.

**Moment de la indústria**

Docker va arribar en el moment perfecte per aprofitar diverses onades tecnològiques. El moviment d'arquitectura de microserveis estava guanyant impuls i els contenidors proporcionaven el mecanisme d'empaquetament perfecte per a serveis petits i independents. La cultura DevOps estava emfatitzant l'automatització i la infraestructura com a codi i l'enfocament declaratiu de Docker encaixava perfectament. Els proveïdors de núvol cercaven maneres d'oferir serveis de computació més eficients i els contenidors proporcionaven millor utilització de recursos que les VMs.


**Ecosistema d'eines**

L'ecosistema d'eines que es va desenvolupar al voltant de Docker no va tenir precedents. Docker Compose va fer que les aplicacions multi-contenidor fossin simples de definir i gestionar. Els sistemes CI/CD van integrar Docker de manera natural, facilitant construir, provar i desplegar aplicacions contenitzades. Les eines de monitorització i registre van afegir suport per a Docker i les plataformes de núvol van oferir serveis de contenidors gestionats. Aquest ecosistema complet va significar que triar Docker no era només triar una tecnologia de contenidors: era unir-se a una plataforma completa de lliurament d'aplicacions.

## Arquitectura

Docker segueix una arquitectura client-servidor amb tres components principals:

```text
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  docker build    docker pull    docker run              │    │
│  └─────────────────────────────────────────────────────────┘    │
└───────────────────────────┬─────────────────────────────────────┘
                            │ REST API
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DOCKER HOST (DAEMON)                         │
│  ┌───────────────────┐  ┌───────────────────────────────────┐   │
│  │    Contenidors    │  │            Imatges                │   │
│  │  ┌─────┐ ┌─────┐  │  │  ┌─────────┐  ┌──────────┐        │   │
│  │  │ App │ │ DB  │  │  │  │  nginx  │  │ postgres │        │   │
│  │  └─────┘ └─────┘  │  │  └─────────┘  └──────────┘        │   │
│  └───────────────────┘  └───────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                        REGISTRY                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Docker Hub    |    Registre privat    |    GHCR        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

El client Docker (`docker`) és la interfície de línia de comandes que l'usuari utilitza per interactuar amb Docker. Envia comandes al daemon a través de l'API REST.

Docker Daemon (`dockerd`) és el servei que s'executa a l'amfitrió i gestiona els objectes Docker: imatges, contenidors, xarxes i volums. Escolta les peticions de l'API i gestiona el cicle de vida dels contenidors.

Registry és el repositori d'imatges Docker. Docker Hub és el registre públic per defecte, però podem configurar registres privats (Harbor, GitLab Container Registry, GitHub Container Registry, etc.) o usar el nostre propi registre usant [la imatge que Docker Hub ofereix](https://hub.docker.com/_/registry).

### Conceptes clau

Abans de passar als articles pràctics, és important tenir clars els conceptes fonamentals:

- **Imatge:** Plantilla de només lectura amb instruccions per crear un contenidor. Inclou el codi de l'aplicació, biblioteques, dependències i configuració.
- **Contenidor:** Instància executable d'una imatge. És un procés aïllat amb el seu propi sistema de fitxers, xarxa i espai de processos.
- **Volum:** Mecanisme per persistir dades generades i usades pels contenidors. Sobreviuen al cicle de vida del contenidor.
- **Xarxa:** Sistema que permet la comunicació entre contenidors i amb l'exterior. Docker proporciona diversos drivers de xarxa.
- **Dockerfile:** Fitxer de text amb instruccions per construir una imatge Docker de manera automatitzada i reproduïble.

## Analogies efectives

L'analogia del *contenidor de transport marítim* continua sent una de les maneres més efectives d'explicar la contenització als nouvinguts. De la mateixa manera que els contenidors de transport van estandarditzar el transport de càrrega proporcionant interfícies consistents independentment del contingut, els contenidors de programari estandarditzen el desplegament d'aplicacions proporcionant entorns d'execució consistents. Podem estendre aquesta analogia comparant Docker Hub amb un port de contenidors on els contenidors estandarditzats poden ser emmagatzemats i enviats a tot el món, i Kubernetes amb el sistema logístic que gestiona contenidors a través de múltiples vaixells i ports.

Una altra analogia útil compara els contenidors amb apartaments en un edifici amb les cases en parcel·les individuals. Les màquines virtuals són com cases individuals: cadascuna té els seus propis serveis, fonaments i infraestructura, proporcionant aïllament complet però requerint recursos significatius. Els contenidors són com apartaments: comparteixen infraestructura comuna (canonades, electricitat, estructura) però proporcionen espais de vida separats. Aquesta analogia ajuda a explicar per què els contenidors són més eficients en recursos mentre destaca les consideracions de seguretat de la infraestructura compartida.

## Casos d'ús

**Docker: estàndard de desenvolupament i de conductes de CI/CD**

Docker s'ha convertit en l'estàndard per a la contenització d'aplicacions en entorns de desenvolupament i integració contínua. La majoria d'aplicacions modernes es desenvolupen amb Docker, fins i tot si es despleguen en altres plataformes en producció. La força de Docker en entorns de desenvolupament local (la capacitat d'iniciar ràpidament bases de dades, cues de missatges i altres dependències) el fa indispensable per a la productivitat del desenvolupador. Els conductes CI/CD usen Docker per a entorns de construcció consistents i empaquetament d'artefactes.

La simplicitat de Docker el fa ideal per a equips nous en contenidors o organitzacions amb experiència limitada en contenidors. Docker Desktop proporciona una manera fàcil d'usar per als desenvolupadors per executar contenidors a les seves estacions de feina i Docker Compose gestiona la majoria d'escenaris multi-contenidor comuns sense requerir experiència en plataformes d'orquestració.

**LXC/LXD: infraestructura i entorns de desenvolupament**

LXC/LXD ha trobat el seu nínxol en escenaris que necessiten funcionalitat similar a VM amb eficiència de contenidor. Els equips d'infraestructura usen contenidors de sistema per a entorns de desenvolupament, executors de CI/CD i modernització d'aplicacions legacy. Les institucions educatives usen LXD per proporcionar als estudiants entorns Linux complets sense la sobrecàrrega de VMs completes. Els proveïdors de núvol ofereixen serveis de contenidors basats en LXD per a clients que necessiten més control del que proporcionen els contenidors Docker.

**Orquestració: Docker Swarm i Kubernetes**

Quan les aplicacions creixen i necessiten executar-se en múltiples servidors, cal una eina d'orquestració que gestioni el desplegament, l'escalat i la recuperació davant fallades.

**Docker Swarm** és la solució d'orquestració nativa de Docker. Permet convertir un grup de màquines amb Docker en un clúster coordinat, on els contenidors es distribueixen automàticament entre els nodes disponibles. El seu principal avantatge és la simplicitat: si ja coneixes Docker i Docker Compose, la [transició a Docker Swarm]({{<relref "/posts/docker/swarm/">}}) és natural, ja que utilitza els mateixos fitxers YAML i comandes similars. Swarm és ideal per a equips petits o mitjans, aplicacions amb requisits d'escalat moderats o organitzacions que volen orquestració sense la complexitat afegida de Kubernetes.

**Kubernetes** s'ha convertit en l'estàndard de facto per a l'orquestració de contenidors en entorns cloud-native de gran escala. Els principals proveïdors de núvol ofereixen serveis de Kubernetes gestionats (EKS, GKE, AKS), i la majoria d'estratègies de contenidors empresarials se centren al voltant de Kubernetes. El seu model declaratiu i l'extens ecosistema el fan adequat per a aplicacions complexes multi-equip que necessiten capacitats sofisticades de desplegament, escalat i gestió.

L'adopció d'orquestració sovint segueix una corba de maduresa: les organitzacions típicament comencen amb Docker per a desenvolupament local, passen a Docker Compose per gestionar aplicacions multi-contenidor, adopten Docker Swarm quan necessiten múltiples servidors i, eventualment, migren a Kubernetes si els seus requisits de complexitat i escala ho justifiquen. No totes les organitzacions necessiten arribar a Kubernetes: moltes aplicacions funcionen perfectament bé amb Docker Swarm durant anys.

## Tecnologies emergents

El paisatge dels contenidors continua evolucionant amb noves tecnologies que aborden limitacions específiques:

**Podman** proporciona una alternativa sense daemon a Docker amb característiques de seguretat millorades. Els contenidors Podman s'executen com a processos d'usuari sense privilegis, eliminant els riscos de seguretat associats amb el daemon Docker que s'executa com a root.

**WebAssembly (WASM)** promet contenidors amb rendiment proper al natiu i fortes garanties d'aïllament, potencialment substituint contenidors tradicionals per a certes càrregues de treball. Els contenidors WASM poden executar-se a qualsevol plataforma que suporti l'entorn d'execució WebAssembly, proporcionant veritable independència de plataforma.

**Firecracker i gVisor** creen micro-VMs o sandboxes de contenidors que proporcionen seguretat similar a VM amb eficiència similar a contenidors.

L'**edge computing** està impulsant el desenvolupament de solucions de contenidors més lleugeres optimitzades per a entorns amb recursos limitats. Tecnologies com K3s (Kubernetes lleuger) i containerd fan l'orquestració de contenidors factible en dispositius edge amb CPU i memòria limitats.

## Seguretat

La seguretat dels contenidors representa un compromís fonamental entre eficiència i aïllament. A diferència de les màquines virtuals, els contenidors comparteixen el nucli del sistema operatiu amfitrió, creant vectors d'atac potencials que no existeixen en entorns de VM. Una vulnerabilitat del nucli podria teòricament permetre l'escapament del contenidor, on un contenidor compromès guanya accés al sistema amfitrió o altres contenidors. Aquest model de nucli compartit també significa que els contenidors han d'executar-se a la mateixa família de SO que l'amfitrió: no pots executar contenidors Windows a amfitrions Linux o viceversa sense capes de virtualització addicionals.

Tanmateix, les plataformes de contenidors modernes han implementat múltiples capes de seguretat per mitigar aquests riscos. Tecnologies com SELinux, AppArmor i seccomp proporcionen controls d'accés obligatoris que limiten el que els processos contenitzats poden fer. Els namespaces d'usuari mapegen els usuaris root del contenidor a usuaris sense privilegis al sistema amfitrió. Les eines de seguretat d'execució de contenidors poden detectar i prevenir comportaments sospitosos en temps real.

## Rendiment

Els contenidors ofereixen característiques de rendiment superiors comparades amb les màquines virtuals en la majoria d'escenaris. Els temps d'inici dels contenidors es mesuren en segons en lloc de minuts perquè no hi ha cap SO convidat per arrencar: els contenidors són simplement nous processos iniciats amb límits d'aïllament. L'ús de memòria és més eficient perquè els contenidors comparteixen el nucli de l'amfitrió i biblioteques comunes, eliminant la duplicació inherent als desplegaments de VM. La sobrecàrrega de CPU és mínima ja que no hi ha cap capa d'hipervisor traduint entre sistemes convidat i amfitrió.

Aquests avantatges de rendiment es fan més pronunciats a escala. Un sistema amfitrió que podria suportar 10-20 VMs sovint pot executar més de 100 contenidors, depenent de les característiques de la càrrega de treball. Aquesta millora de densitat es tradueix directament en estalvi de costos en entorns de núvol on pagues per recursos de computació.

## Conceptes erronis comuns

Un dels conceptes erronis més persistents és que els contenidors són només *VMs lleugeres*. Mentre que aquesta comparació ajuda a explicar l'eficiència de recursos, és important aclarir que els contenidors usen mecanismes d'aïllament fonamentalment diferents. Les VMs proporcionen aïllament a nivell de maquinari a través d'hipervisors, mentre que els contenidors usen aïllament a nivell de SO a través de funcionalitats del nucli. Aquesta distinció afecta els models de seguretat, les característiques de rendiment i les consideracions operatives.

Un altre concepte erroni comú és que contenitzar una aplicació automàticament la fa *cloud-native* o adequada per a arquitectures de microserveis. Els contenidors són simplement un mecanisme d'empaquetament: una aplicació monolítica en un contenidor continua sent monolítica. Els contenidors permeten certs patrons arquitectònics però no transformen automàticament el disseny de l'aplicació. Els beneficis reals vénen de dissenyar aplicacions per aprofitar les característiques dels contenidors com la immutabilitat, l'escalat horitzontal i el desplegament ràpid.
