---
title: "Write-Ahead Log"
date: 2025-03-24
---

A Write-Ahead Log (WAL) is a standard method for ensuring data integrity. Its central concept is that changes to data files must be written only after those changes have been logged, that is, after WAL records describing the changes have been flushed to permanent storage.

