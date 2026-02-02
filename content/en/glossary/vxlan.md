---
title: "Virtual Extensible LAN"
date: 2026-02-01
---

Virtual Extensible [*](LAN) (VXLAN) is a network virtualization technology that encapsulates Layer 2 Ethernet frames within Layer 4 UDP datagrams, enabling the creation of scalable virtual networks over an underlying Layer 3 IP infrastructure.

It was developed to overcome the scalability limitations of traditional VLANs, which are restricted to 4,094 logical networks due to their 12-bit VLAN ID. VXLAN uses a 24-bit Virtual Network Identifier (VNI), allowing up to approximately 16 million unique network segments, making it ideal for large-scale data centers and cloud environments.

VXLAN operates through VXLAN Tunnel Endpoints (VTEPs), which encapsulate and decapsulate traffic, enabling virtual machines across different physical locations to communicate as if on the same local network while maintaining Layer 2 semantics. It is standardized by the IETF in [RFC 7348](https://www.rfc-editor.org/rfc/rfc7348.txt).
