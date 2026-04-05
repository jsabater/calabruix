---
title: "Python per a administradors de sistemes"
description: "Fonaments de programació i scripting amb Python orientat a l'administració de sistemes"
summary: "Fonaments de programació i scripting amb Python orientat a l'administració de sistemes"
categories: ["teaching"]
tags: ["python", "scripting"]
---

Aquests articles són els apunts de classe d'una unitat temàtica de l'assignatura Implantació de Sistemes Operatius del primer curs del CFGS en Administració de Sistemes Informàtics i Xarxes al CIFP [Francesc de Borja Moll](https://cifpfbmoll.eu/) de Palma.

Aquesta sèrie introdueix la programació amb Python des d'una perspectiva pràctica orientada a l'administració de sistemes. La primera part cobreix els fonaments de programació (algorismes, variables, estructures de control, funcions i bones pràctiques) sempre amb exemples relacionats amb tasques d'administració. La segona part se centra en scripting: manipulació de fitxers, expressions regulars, execució de comandes, gestió de processos i automatització.

L'objectiu és que l'alumnat adquireixi les habilitats necessàries per automatitzar tasques repetitives, crear eines d'administració i entendre scripts existents.

## Continguts de la sèrie

La sèrie està dividida en dues parts.

### Part I: Fonaments de programació

1. [Introducció a Python i algorismes]({{<relref "/posts/scripting/introduction/">}}): Primers passos amb Python: què és un algorisme, instal·lació, l'intèrpret interactiu, primer script i permisos d'execució.
2. [Variables i tipus de dades]({{<relref "/posts/scripting/variables/">}}): Variables, tipus bàsics, conversions, f-strings i entrada de dades.
3. [Col·leccions de dades]({{<relref "/posts/scripting/">}}): Llistes, tuples, diccionaris i conjunts per organitzar informació.
4. [Expressions i operadors]({{<relref "/posts/scripting/">}}): Operadors aritmètics, de comparació, lògics i de pertinença.
5. [Estructures de control]({{<relref "/posts/scripting/">}}): Decisions amb if, elif, else i match-case.
6. [Bucles]({{<relref "/posts/scripting/">}}): Repetició amb for i while, range, enumerate i comprensions.
7. [Funcions]({{<relref "/posts/scripting/">}}): Definició de funcions, paràmetres, retorn i documentació.
8. [Bones pràctiques i depuració]({{<relref "/posts/scripting/">}}): PEP 8, gestió d'errors, logging i eines d'anàlisi de codi.

### Part II: Scripting per a administració

9. [Fitxers i directoris]({{<relref "/posts/scripting/">}}): Lectura, escriptura i manipulació de fitxers amb pathlib.
10. [Text i expressions regulars]({{<relref "/posts/scripting/">}}): Processament de text i patrons amb el mòdul re.
11. [Execució de comandes]({{<relref "/posts/scripting/">}}): Integració amb el sistema mitjançant subprocess.
12. [Arguments i variables d'entorn]({{<relref "/posts/scripting/">}}): Scripts parametritzables amb argparse i configuració amb variables d'entorn.
13. [Gestió de processos]({{<relref "/posts/scripting/">}}): Monitoratge de processos i recursos amb psutil.
14. [Xarxes bàsiques]({{<relref "/posts/scripting/">}}): Validació d'IPs, comprovació de ports i peticions HTTP.
15. [Automatització de tasques]({{<relref "/posts/scripting/">}}): Integració amb cron, systemd i logging avançat.
16. [Projecte final]({{<relref "/posts/scripting/">}}): Eina d'administració completa que integra els conceptes del curs.