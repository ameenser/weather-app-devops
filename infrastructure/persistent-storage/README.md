# Persistent storage root

This Terraform root owns storage whose lifetime is intentionally independent
from the main EKS/EC2 stack. A main-stack `terraform destroy` must not be run
from this directory.

It adopts the surviving GitLab, Jenkins, Prometheus, Grafana, Alertmanager, and
Vault volumes and creates one fresh n8n volume. The previous n8n volume was
deleted, and no EBS snapshot exists for it, so its old data cannot be restored.

## Safety model

- This root uses a separate S3 state key.
- Every EBS volume has `prevent_destroy = true`.
- AWS Backup keeps daily recovery points for 30 days by default.
- EBS Recycle Bin keeps accidentally deleted tagged volumes for 7 days.
- Kubernetes PVs use `Retain` and statically reference these EBS volumes.

`prevent_destroy` only protects Terraform actions made while the lifecycle
block remains in configuration. AWS Backup and Recycle Bin protect against
other deletion paths.

## Phase 1: review and adopt storage

Create an untracked input file:

```bash
cd persistent-storage
cp terraform.tfvars.example terraform.tfvars
```

Fill the six live EBS IDs. The GitLab and Jenkins IDs are already present in
the main root's untracked `terraform.tfvars`. The monitoring and Vault IDs can
be read from their PVs:

```bash
kubectl get pv -o custom-columns='PV:.metadata.name,VOLUME:.spec.csi.volumeHandle,CLAIM:.spec.claimRef.name'
```

Then review without applying:

```bash
terraform init
terraform plan
```

On a fresh state, the first plan must show exactly six EBS imports and one new
EBS volume named `weather-app-n8n`. It must show no EBS destroy or replacement.
Stop if it does.

## Phase 2: connect the new n8n volume

Only after the Phase 1 plan has been approved and applied, obtain the ID:

```bash
terraform output -raw n8n_volume_id
```

Replace the deleted `volumeHandle` in
`weather-app-gitops/platform/n8n-storage/persistentvolume.yaml` with that ID,
then review and push the GitOps diff. Do not sync it over the existing PV/PVC:
Kubernetes treats the PV `volumeHandle` and bound PVC `volumeName` as immutable.

Use this migration sequence during a short n8n maintenance window:

1. Temporarily disable automated sync for the n8n Argo CD Application.
2. Scale `deployment/n8n-main` in namespace `n8n` to zero.
3. Delete the stale `n8n` PVC and its old PV. The old EBS volume is already
   absent, so there is no remaining disk to delete.
4. Sync the updated n8n Application so Argo CD recreates the static PV/PVC with
   the new volume ID.
5. Re-enable automated sync and confirm the n8n Pod becomes ready.

The new n8n instance will start empty because no snapshot of the deleted volume
exists. Never format a restored EBS volume manually; the EBS CSI driver formats
the new empty n8n volume as `ext4` on its first mount.

## Main-stack destroy check

Run `terraform plan -destroy` from the main Terraform root. The plan may delete
volume attachments and Kubernetes resources, but it must not list any of the
persistent EBS volumes for deletion.
