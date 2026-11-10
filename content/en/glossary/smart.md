---
title: "Self-Monitoring, Analysis, and Reporting Technology"
date: 2026-11-09
---

Self-Monitoring, Analysis, and Reporting Technology (S.M.A.R.T.) is a monitoring system built into the firmware of nearly all modern storage devices. Its primary function is to detect and report various indicators of drive reliability in order to predict imminent hardware failures before they occur.

The drive's internal sensors and counters continuously track attributes such as temperature, power-on hours, read/write error rates, reallocated sector counts, and (for SSDs) available spare capacity and flash endurance. Each attribute is assigned a normalized value and a vendor-defined threshold; when the value drops below the threshold, the drive is flagged as "failing" and a warning is sent to the host system (often visible during BIOS/UEFI startup).

Drives may also support optional self-test routines (short and extended) whose results are stored in a self-test log. SMART does not repair hardware or guarantee that every failure is predictable, but it provides an early-warning mechanism that allows users to back up data or replace a drive before a catastrophic loss occurs.
