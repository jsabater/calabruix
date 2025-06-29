---
title: "2nd Level Adaptive Replacement Cache"
date: 2024-09-16
---

The ZFS 2nd Level Adaptive Replacement Cache (L2ARC) is an SSD based cache that is accessed before reading from the much slower pool disks.

When a system gets read requests, ZFS uses ARC (RAM) to serve those requests. When the ARC is full and there are L2ARC drives allocated to a ZFS pool, ZFS uses the L2ARC to serve the read requests that overflowed from the ARC. This reduces the use of slower hard drives and therefore increases system performance.

The L2ARC is currently intended for random read workloads.
