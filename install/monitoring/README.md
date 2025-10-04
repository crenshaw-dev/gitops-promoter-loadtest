# Monitoring Setup

This directory contains Prometheus and Grafana monitoring for GitOps Promoter and Argo CD load testing.

## What Gets Installed

- **Prometheus**: Metrics collection with 24h retention
- **Grafana**: Visualization with pre-configured dashboards
- **ServiceMonitors**: Scrape configs for Promoter and Argo CD components
- **Dashboards**: Placeholder dashboards for Promoter and Argo CD (to be populated)

## Installation

**Note**: This monitoring stack uses Kustomize's Helm chart inflation feature. You need to enable Helm support:

```bash
# Apply with Helm support enabled
kubectl kustomize --enable-helm install/ | kubectl apply -f -

# Or using kustomize directly
kustomize build --enable-helm install/ | kubectl apply -f -
```

## Components

### Prometheus Stack

Installed via `kube-prometheus-stack` Helm chart using Kustomize's Helm chart inflation:

- **Prometheus**: Configured to scrape all ServiceMonitors
- **Grafana**: Admin credentials: `admin`/`admin`
- **Kube State Metrics**: Kubernetes resource metrics
- **Node Exporter**: Node-level metrics

### ServiceMonitors

#### Promoter
- **promoter-controller**: Scrapes GitOps Promoter controller metrics endpoint

#### Argo CD
- **argocd-metrics**: Application controller metrics
- **argocd-server-metrics**: API server metrics
- **argocd-repo-server-metrics**: Repository server metrics
- **argocd-applicationset-controller-metrics**: ApplicationSet controller metrics

### Dashboards

Two placeholder dashboards are provided as ConfigMaps:

1. **GitOps Promoter Dashboard** (`grafana-dashboard-promoter`)
   - TODO: Add panels for:
     - Reconciliation rates and latency
     - PullRequest creation/merge times
     - PromotionStrategy health
     - ChangeTransferPolicy status
     - Controller resource usage

2. **Argo CD Dashboard** (`grafana-dashboard-argocd`)
   - TODO: Add panels for:
     - Application sync status
     - Sync duration
     - Source Hydrator performance
     - API server request rate
     - Controller resource usage

## Accessing Grafana

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open browser to http://localhost:3000
# Login: admin / admin
```

## Accessing Prometheus

```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser to http://localhost:9090
```

## Querying Metrics

### Promoter Metrics

Example queries (once metrics are available):

```promql
# Reconciliation rate
rate(controller_runtime_reconcile_total{controller="promotionstrategy"}[5m])

# Reconciliation errors
rate(controller_runtime_reconcile_errors_total{controller="promotionstrategy"}[5m])

# Reconciliation duration (p95)
histogram_quantile(0.95, rate(controller_runtime_reconcile_time_seconds_bucket[5m]))
```

### Argo CD Metrics

Example queries:

```promql
# Application sync status
argocd_app_info

# Sync operations per second
rate(argocd_app_sync_total[5m])

# Sync duration (p95)
histogram_quantile(0.95, rate(argocd_app_sync_duration_seconds_bucket[5m]))
```

## Updating Dashboards

The dashboard JSON files are in `dashboards/`:

1. Edit the dashboard in Grafana UI
2. Export the dashboard JSON (Dashboard Settings → JSON Model)
3. Replace the contents of the corresponding file:
   - `dashboards/promoter-dashboard.json`
   - `dashboards/argocd-dashboard.json`
4. Reapply: `kubectl apply -k install/`
5. Restart Grafana to reload: `kubectl rollout restart -n monitoring deployment/kube-prometheus-stack-grafana`

## Resource Requirements

The monitoring stack is configured with conservative resource requests for local testing:

- **Prometheus**: 200m CPU, 512Mi memory
- **Grafana**: 100m CPU, 128Mi memory
- **Prometheus Operator**: 100m CPU, 128Mi memory
- **Kube State Metrics**: Default limits
- **Node Exporter**: Default limits

Adjust these in `kustomization.yaml` if needed for larger deployments.

## Troubleshooting

### ServiceMonitor not scraping

Check if the ServiceMonitor is being picked up:

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
```

### Dashboard not showing

1. Verify ConfigMaps are created:
   ```bash
   kubectl get cm -n monitoring | grep grafana-dashboard
   ```

2. Check Grafana logs:
   ```bash
   kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana
   ```

3. Restart Grafana:
   ```bash
   kubectl rollout restart -n monitoring deployment/kube-prometheus-stack-grafana
   ```

