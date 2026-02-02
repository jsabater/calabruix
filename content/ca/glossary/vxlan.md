---
title: "LAN Virtual Extensible"
date: 2026-02-01
---

Una [*](LAN) Virtual Extensible (VXLAN) és una tecnologia de virtualització de xarxa que encapsula trames Ethernet de nivell 2 dins de datagrames UDP de nivell 4, permetent la creació de xarxes virtuals escalables sobre una infraestructura IP de nivell 3 subjacent. 

Va ser desenvolupada per superar les limitacions d'escalabilitat de les VLAN tradicionals, que es limiten a 4.094 xarxes lògiques degut al seu identificador VLAN de 12 bits. VXLAN utilitza un identificador de xarxa virtual (VNI) de 24 bits, permetent fins a uns 16 milions de segments de xarxa únics, ideal per a centres de dades a gran escala i entorns de nigul.

VXLAN opera mitjançant punts finals de túnel VXLAN (VTEPs), que encapsulen i desencapsulen el tràfic, permetent que màquines virtuals en ubicacions físiques diferents comuniquin com si estiguessin a la mateixa xarxa local, mantenint la semàntica de nivell 2. Està estandarditzat per l’IETF a l'[RFC 7348](https://www.rfc-editor.org/rfc/rfc7348.txt).
