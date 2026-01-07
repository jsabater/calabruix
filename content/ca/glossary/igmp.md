---
title: "Internet Group Management Protocol"
date: 2025-02-10
---

L'Internet Group Management Protocol (IGMP) és el protocol que permet la comunicació multicast permetent als dispositius unir-se i abandonar grups multicast. En lloc d'enviar les mateixes dades a cada node individualment (unicast), el multicast permet que les dades s'enviïn una vegada i les rebin tots els nodes que s'han unit al grup multicast corresponent.

Aquesta comunicació multicast, facilitada per IGMP, és crucial perquè els clústers mantinguin el quòrum (assegurant que la majoria de nodes estiguin disponibles) i per a altres tasques relacionades amb clústers. Perquè IGMP i el multicast funcionin correctament en un clúster, els commutadors físics de la xarxa han de ser conscients del multicast i capaços d'IGMP snooping.
