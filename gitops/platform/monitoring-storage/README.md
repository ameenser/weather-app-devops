# Monitoring persistent storage

These manifests pre-bind Prometheus, Grafana, and Alertmanager to their
existing EBS volumes. They intentionally preserve the current PVC and PV names
because the Prometheus Operator derives its StatefulSet claim names from the
release name and replica index.

The EBS volumes are zonal. Keep each PV's `nodeAffinity` aligned with its
volume's Availability Zone. Do not change a `volumeHandle` unless restoring
from a snapshot into a new EBS volume.

The `Retain` reclaim policy prevents PVC deletion from requesting EBS deletion.
Terraform ownership, backups, and deletion protection live in the separate
`golden-ami-terraform/persistent-storage` root.
