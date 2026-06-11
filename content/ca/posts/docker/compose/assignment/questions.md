# Preguntes per a la defensa oral

## Fonaments i estructura (1-8)

1. Per què el fitxer es diu `compose.yaml` i no `docker-compose.yml`?
2. Quina diferència hi ha entre `docker compose up` i `docker compose up --build`?
3. Què fa l'opció `--detach` o `-d`?
4. Com pots veure els logs d'un servei concret?
5. Quina comanda uses per veure l'estat de tots els serveis?
6. Com accedeixes a una shell dins un contenidor que ja està en execució?
7. Quina diferència hi ha entre `docker compose down` i `docker compose down -v`?
8. Per què has organitzat els Dockerfiles dins el directori `docker/`?

## Variables d'entorn i configuració (9-16)

9. Per què no has posat les contrasenyes directament al `compose.yaml`?
10. Quina diferència hi ha entre `.env` i `.env.example`?
11. Com sap Docker Compose que ha de llegir el fitxer `.env`?
12. Què passa si una variable del `.env` no està definida?
13. Com pots veure les variables d'entorn d'un contenidor en execució?
14. Per què el `.env` està al `.gitignore`?
15. Quina sintaxi uses per assignar un valor per defecte a una variable?
16. Com verificaries que les variables s'han substituït correctament abans d'arrencar?

## Xarxes (17-24)

17. Per què has creat més d'una xarxa?
18. Quins serveis estan a la xarxa de backend i per què?
19. Per què Traefik necessita accés a múltiples xarxes?
20. Pot el servei de base de dades comunicar-se directament amb Nginx? Per què?
21. Com es resolen els noms dels serveis dins una xarxa Docker?
22. Quina diferència hi ha entre una xarxa bridge i una xarxa overlay?
23. Com pots inspeccionar quins contenidors estan connectats a una xarxa?
24. Per què no has exposat el port de PostgreSQL a l'amfitrió?

## Volums i persistència (25-30)

25. Quins serveis tenen volums i per què?
26. Quina diferència hi ha entre un volum amb nom i un bind mount?
27. On es guarden físicament les dades d'un volum amb nom?
28. Què passaria si fessis `docker compose down -v` i tornessis a arrencar?
29. Per què el volum de PostgreSQL apunta a `/var/lib/postgresql` i no a `/var/lib/postgresql/data`?
30. Com pots fer una còpia de seguretat de les dades d'un volum?

## Healthchecks i dependències (31-38)

31. Per què has configurat healthchecks als serveis?
32. Quina diferència hi ha entre `service_started` i `service_healthy`?
33. Quan usaries `service_completed_successfully`?
34. Què passa si un healthcheck falla repetidament?
35. Com has verificat que PostgreSQL està llest per rebre connexions?
36. Quin és l'interval del healthcheck de l'API i per què?
37. Què significa `start_period` en un healthcheck?
38. Com pots veure l'estat de salut d'un contenidor?

## Dockerfiles i imatges (39-46)

39. Quins errors has trobat al Dockerfile original de l'API?
40. Per què és important l'ordre de les instruccions en un Dockerfile?
41. Què és un multi-stage build i quan l'usaries?
42. Per què uses un usuari no privilegiat al Dockerfile?
43. Quina diferència hi ha entre `COPY` i `ADD`?
44. Per què copies primer el `requirements.txt` i després la resta del codi?
45. Què fa la instrucció `EXPOSE`? És obligatòria?
46. Quina diferència hi ha entre `CMD` i `ENTRYPOINT`?

## Extensions YAML i optimització (47-52)

47. Què són les extensions YAML i per què les has usat?
48. Com funciona la sintaxi `<<: *nom`?
49. Quines configuracions has extret a extensions reutilitzables?
50. Què indica el prefix `x-` en un bloc YAML?
51. Com es combinen els valors quan uses `<<:` amb valors locals?
52. Quins avantatges té usar extensions respecte a copiar i enganxar?

## Perfils i entorns (53-56)

53. Com arrenques l'entorn en mode desenvolupament?
54. Per què Adminer i Mailpit no s'arrenquen per defecte?
55. Quina diferència hi ha entre usar perfils i usar `compose.override.yaml`?
56. Com pots veure quins perfils estan actius?

## Traefik i proxy invers (57-62)

57. Per què uses Traefik en lloc de Nginx com a proxy invers?
58. Com descobreix Traefik els serveis automàticament?
59. Què significa `exposedByDefault=false`?
60. Com has configurat el routing per a l'API i el frontend?
61. Què fa l'etiqueta `traefik.enable=true`?
62. Com accediries al dashboard de Traefik?

## Límits de recursos (63-66)

63. Per què has definit límits de memòria als serveis?
64. Quina diferència hi ha entre `limits` i `reservations`?
65. Com has decidit els valors de CPU i memòria per a cada servei?
66. Què passa si un contenidor supera el límit de memòria?

## Docker Hub i publicació (67-72)

67. Quines imatges has publicat a Docker Hub i per què?
68. Quina estratègia d'etiquetatge has seguit?
69. Quina comanda uses per autenticar-te a Docker Hub?
70. Quina diferència hi ha entre `docker build` i `docker compose build`?
71. Com etiquetes una imatge abans de pujar-la?
72. Per què no has pujat les imatges oficials (PostgreSQL, Redis, etc.)?

## Resolució de problemes (73-78)

73. Com diagnosticaries per què un servei no arrenca?
74. Un servei està en estat "unhealthy". Com ho investigaries?
75. L'API no es connecta a PostgreSQL. Quins passos seguiries?
76. Com verificaries que Traefik encamina correctament les peticions?
77. Com pots veure quants recursos consumeix cada contenidor?
78. Com reiniciaries un servei sense afectar els altres?

## Conceptes generals (79-82)

79. Quina diferència hi ha entre un contenidor i una imatge?
80. Què és el principi de mínim privilegi i com l'has aplicat?
81. Per què és important que cada commit deixi el projecte funcional?
82. Quins canvis faries per portar aquest entorn a producció real?
