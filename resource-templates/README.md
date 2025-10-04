# Kubernetes Resource Templates

This directory contains templates for Kubernetes resources that will be deployed to your clusters. These templates are **not overridable** - they define the core infrastructure for the load test.

## Structure

```
resource-templates/
├── promoter/           # Resources for the GitOps Promoter cluster
│   ├── github-app-secret.yaml.tpl
│   ├── cluster-scm-provider.yaml.tpl
│   ├── promoter-namespace.yaml.tpl
│   ├── git-repository.yaml.tpl
│   ├── promotion-strategy.yaml.tpl
│   └── argocd-commit-status.yaml.tpl
├── argo/              # Resources for the Argo CD cluster
│   ├── appproject.yaml.tpl
│   ├── repo-write-creds-secret.yaml.tpl
│   └── argocd-app.yaml.tpl
└── destination/       # Resources for the destination cluster
    └── destination-namespace.yaml.tpl
```

## Purpose

These templates define the GitOps Promoter and Argo CD resources needed to run the load test:

- **Promoter resources**: GitHub App configuration, SCM provider, Git repositories, promotion strategies, and Argo CD commit status watchers
- **Argo CD resources**: App projects, applications, and repository credentials
- **Destination resources**: Namespaces where applications will be deployed

## Customizing Repository Content

If you want to customize what gets pushed to the **git repositories** (not the Kubernetes resources), use the `repo-templates/` and `repo-templates.local/` directories instead.

