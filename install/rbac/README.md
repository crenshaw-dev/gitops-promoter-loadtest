# RBAC Configuration

This directory contains cluster-scoped RBAC resources that are applied separately from namespaced resources to avoid kustomize namespace transformation issues.

## Resources

### `promoter-metrics-rbac.yaml`

Configures RBAC permissions for Prometheus to scrape GitOps Promoter metrics.

GitOps Promoter's metrics endpoint is protected by [kube-rbac-proxy](https://github.com/brancz/kube-rbac-proxy), which requires:

1. **`promoter-metrics-reader` ClusterRole** (provided by GitOps Promoter)
   - Allows reading `/metrics` endpoint

2. **`promoter-proxy-role` ClusterRole** (provided by GitOps Promoter)
   - Allows creating `tokenreviews` and `subjectaccessreviews` for authentication validation

This file creates two ClusterRoleBindings that grant these permissions to the Prometheus service account (`kube-prometheus-stack-prometheus` in the `monitoring` namespace).

## Why a Separate Directory?

The main `monitoring/` kustomization has `namespace: monitoring` set, which causes kustomize to add that namespace to all resources. This is fine for namespaced resources like ServiceMonitors, but breaks ClusterRole and ClusterRoleBinding resources which are cluster-scoped and cannot have a namespace.

By putting these resources in a separate kustomization without namespace transformation, we can include them in the main installation while keeping them cluster-scoped.

