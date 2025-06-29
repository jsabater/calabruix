---
title: "Moving Loki's long-term storage to MinIO"
date: 2025-05-24
lastmod: 2025-05-24
description: "Using MinIO as long-term storage with Loki"
summary: "Moving long-term storage of logs to MinIO in our Loki instance"
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "loki"]
series: ["Grafana"]
series_order: 22
draft: true
---

An alternative approach for our long-term storage would be to use the S3-compatible [MinIO Object Store](https://min.io/). To do so, we need to update two sections of our `/etc/loki/config.yml` file.

Update the `schema_config` to:

```yaml
schema_config:
  configs:
    - from: "2024-01-01"
      store: tsdb
      object_store: s3
      schema: v13
      index:
        prefix: index_
        period: 24h
      chunks:
        prefix: chunks_
        period: 24h
```

And add the corresponding `storage_config` block:

```yaml
storage_config:
  aws:
    s3: https://minio1.localdomain.com
    access_key_id: <access_key_id>
    secret_access_key: <secret_access_key>
    s3forcepathstyle: true
    bucketnames: loki-data
  tsdb_shipper:
    active_index_directory: /var/lib/loki/tsdb-shipper-active
    cache_location: /var/lib/loki/tsdb-shipper-cache
    shared_store: s3
```

## TSDB with local storage vs. S3 Object Storage

When using TSDB with local storage:

* Setup. Logs are stored locally on the disk in TSDB format (Time-Series Database). Metadata indexes (labels) are stored using a local key-value store (e.g., BoltDB).
* Performance. Faster read/write operations due to local storage proximity. Limited by the size of local disks.
* Use case. Best suited for small-scale deployments or testing environments where scalability is not critical.
* Maintenance. Requires manual handling of disk space and backups. Relatively simple to configure and maintain.

When using S3 for storage:

* Setup. Logs (chunks) are stored in the S3 object storage system. Metadata indexes are often stored in cloud-based key-value stores like DynamoDB or Bigtable.
* Performance. Write speed depends on network and storage service latency.
* Use case. Best suited for large-scale, distributed deployments with high availability requirements.
* Scalability. Nearly unlimited storage capacity with automatic scaling. Allows multi-region redundancy and disaster recovery capabilities.
* Maintenance. Offloads storage management to the cloud provider. Can incur higher operational costs compared to local storage.
