# Rúbrica d'avaluació

| Criteri | Excel·lent (100%) | Bé (75%) | Suficient (50%) | Insuficient (0%) | Pes |
|:--------|:-------------------|:---------|:-----------------|:------------------|:----|
| El clúster funciona amb 3 nodes i l'etiqueta `database=true` | Clúster complet, etiqueta correcta, documentat | Clúster funcional, documentació incompleta | Clúster amb 2 nodes o sense etiqueta | Clúster no funcional o no documentat | 10 |
| Secrets creats amb script automatitzat i `.gitignore` correcte | Script funcional, tots els secrets creats, cap credencial al repo | Secrets creats manualment o `.gitignore` incomplet | Falten secrets o l'script no funciona | Secrets no creats o credencials al repositori | 15 |
| Traefik configurat com a proxy invers amb HTTPS i dashboard | Configuració completa, HTTPS funcional, dashboard accessible | Configuració amb errors menors o sense redirecció HTTP | Traefik desplegat però no funcional com a proxy | Traefik no configurat | 10 |
| El `docker-stack.yml` defineix correctament tots els serveis, xarxes i volums | Tots els serveis correctes, xarxes i volums adequats, rolling update configurat | Algun servei amb errors menors o configuració incompleta | Múltiples errors però l'stack es desplega parcialment | L'stack no es desplega o no és lliurat | 25 |
| La imatge es construeix i es publica amb etiqueta de versió | Imatge publicada amb versió semàntica, documentada | Imatge publicada amb `latest` | Imatge construïda però no publicada | Imatge no construïda | 5 |
| L'aplicació funciona, es demostra el routing mesh i la resiliència | Totes les verificacions fetes i documentades | Aplicació accessible però verificacions incompletes | Algunes verificacions fetes | No es demostra el funcionament | 10 |
| Rolling update executat correctament | Update documentat amb observacions del procés | Update executat però sense documentar el procés | Intent d'update amb errors | Update no intentat | 10 |
| `README.md` complet amb passos, respostes i reflexió | Totes les respostes completes i raonades, documentació excel·lent | Respostes correctes però poc desenvolupades | Respostes incompletes o documentació desorganitzada | `README.md` absent o respostes incorrectes | 15 |

Penalitzacions:

* Credencials reals dins el lliurament: -20 punts.
* Lliurament fora de termini (fins a 48h): -20 punts.
* Lliurament fora de termini: No s'accepta.

La nota final es calcula com la suma ponderada de cada criteri. Per aprovar la pràctica cal obtenir un mínim de **50 punts** i no tenir cap criteri amb 0 punts a les tasques 2, 4 o 6 (considerades essencials).
