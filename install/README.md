# Local Installation for Load Testing

This directory contains Kustomize manifests to install Argo CD and GitOps Promoter on your local cluster for load testing.

## What Gets Installed

- **Argo CD** (stable version with Source Hydrator) with:
  - Source Hydrator enabled (for rendered manifest pattern)
  - Commit server component deployed
  - GitOps Promoter UI extension
  - Deep links integration for PRs
  - 30s reconciliation timeout (for local testing without webhooks)

- **GitOps Promoter** (v0.13.0) with:
  - 30s requeue durations for all controllers (for local testing without webhooks)

## Prerequisites

- `kubectl` CLI
- Local Kubernetes cluster (e.g., kind, k3d, minikube, Docker Desktop)
- `kustomize` CLI (optional - kubectl has built-in kustomize support)

## Installation

Install both Argo CD and GitOps Promoter with a single command:

```bash
kubectl apply -k install/
```

Or using kustomize directly:

```bash
kustomize build install/ | kubectl apply -f -
```

## Verify Installation

### Check Argo CD

```bash
# Wait for Argo CD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd
```

### Check GitOps Promoter

```bash
# Wait for GitOps Promoter to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/promoter-controller-manager -n promoter-system
```

## Access Argo CD UI

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then visit: https://localhost:8080

- Username: `admin`
- Password: (from the command above)

## Configuration Highlights

### Source Hydrator

The installation uses Argo CD's `install-with-hydrator.yaml` which includes:
- The commit server component for pushing hydrated manifests
- Source Hydrator enabled (`hydrator.enabled: "true"`)
- Support for the rendered manifest pattern

This allows Argo CD Applications to use the `sourceHydrator` field to push rendered Kubernetes manifests to Git before syncing. See the [Argo CD Source Hydrator documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/source-hydrator/) for more details.

### Argo CD Reconciliation

The `timeout.reconciliation` is set to `30s` instead of the default `3m`. This is because:
- Local testing typically doesn't have webhook ingress configured
- GitHub webhooks can't reach `localhost`
- Faster polling helps the load test run more smoothly

### GitOps Promoter Requeue Durations

All controller requeue durations are set to `30s` instead of the default `5m` for the same reason - no webhooks on local clusters.

## Uninstallation

To remove everything:

```bash
kubectl delete -k install/
```

Or if you want to remove namespaces too:

```bash
kubectl delete -k install/
kubectl delete namespace argocd
kubectl delete namespace promoter-system
```

## Customization

To customize the installation:

1. Edit the patches in `argocd/` or `promoter/`
2. Reapply: `kubectl apply -k install/`

For example, to change reconciliation timeouts:
- Edit `argocd/argocd-cm-patch.yaml` for Argo CD
- Edit `promoter/controller-config-patch.yaml` for GitOps Promoter

## References

- [Argo CD Installation](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [GitOps Promoter Getting Started](https://gitops-promoter.readthedocs.io/en/latest/getting-started/)
- [GitOps Promoter Argo CD Integrations](https://gitops-promoter.readthedocs.io/en/latest/argocd-integrations/)
- [GitOps Promoter CRD Specs](https://gitops-promoter.readthedocs.io/en/latest/crd-specs/)

