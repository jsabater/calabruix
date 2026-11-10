---
title: "Self-Monitoring, Analysis, and Reporting Technology"
date: 2026-11-09
---

Self-Monitoring, Analysis, and Reporting Technology (S.M.A.R.T.) és un sistema de monitorització integrat al firmware de gairebé tots els dispositius d'emmagatzematge moderns. La seva funció principal és detectar i informar sobre diversos indicadors de fiabilitat del disc per poder predir falles de maquinari inminents abans que es produeixin.

Els sensors i comptadors interns del disc segueixen de manera contínua atributs com la temperatura, les hores d'ençeniment, les taxes d'error de lectura/escriptura, el nombre de sectors reassignats i (en el cas dels SSD) la capacitat de reserva disponible i l'endurans del flash. A cada atribut se li assigna un valor normalitzat i un llindar definit pel fabricant; quan el valor baixa per sota del llindar, el disc es marca com a "en fallament" i s'envia un avís al sistema amfitrió (sovint visible durant l'inici de BIOS/UEFI).

Els discs també poden suportar rutines de prova automàtica opcionals (curta i estesa) els resultats de les quals es desen a un registre de proves. S.M.A.R.T. no repara el maquinari ni garanteix que totes les falles siguin previsible, però proporciona un mecanisme d'avís precoç que permet als usuaris fer una còpia de seguretat de les dades o substituir el disc abans que es produeixi una pèrdua catastròfica.
