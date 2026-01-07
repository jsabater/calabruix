---
title: "Internet Group Management Protocol"
date: 2025-02-10
---

The Internet Group Management Protocol (IGMP) is the protocol that enables multicast communication by allowing devices to join and leave multicast groups. Instead of sending the same data to each node individually (unicast), multicast allows the data to be sent once and received by all nodes that have joined the relevant multicast group.

This multicast communication, facilitated by IGMP, is crucial for clusters to maintain quorum (ensuring a majority of nodes are available) and for other cluster-related tasks. For IGMP and multicast to work correctly in a cluster, the physical switches in the network need to be multicast-aware and IGMP snooping capable.
