# Teardown Summary - 2025-10-04-17-15-09

## Teardown Completed
- **Date:** Sat Oct  4 17:16:44 EDT 2025
- **Run Directory:** runs/2025-10-04-17-15-09

## Kubernetes Resources Deleted

- **Promoter cluster:** GitRepository, PromotionStrategy, ArgoCDCommitStatus resources, namespaces, ClusterScmProvider, Secret
- **Argo CD cluster:** Applications, AppProjects, repo credential Secrets
- **Destination cluster:** Namespaces

## GitHub Resources Preserved

GitHub repositories and apps were **NOT** deleted. They can be reused for future tests.

To manually delete if needed:
- Repositories are listed in: runs/2025-10-04-17-15-09/logs/SETUP_SUMMARY.md
- GitHub App details in: runs/2025-10-04-17-15-09/logs/SETUP_SUMMARY.md

## Verification

Verify all Kubernetes resources are deleted:
```bash
# Check promoter cluster
kubectl get namespaces -l load-test-run=2025-10-04-17-15-09
kubectl get gitrepositories,promotionstrategies,argocdcommitstatuses -A

# Check Argo CD cluster
kubectl get applications -n argocd
kubectl get appprojects -n argocd

# Check destination cluster
kubectl get namespaces -l load-test-run=2025-10-04-17-15-09
```

## Logs

- Setup log: runs/2025-10-04-17-15-09/logs/setup.log
- Teardown log: runs/2025-10-04-17-15-09/logs/teardown.log
