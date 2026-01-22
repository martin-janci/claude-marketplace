# Kubernetes Toolkit

Comprehensive Kubernetes operations toolkit with skills for cluster management, debugging, manifest generation, deployment automation, and k9s terminal UI.

## Skills

| Skill | Description |
|-------|-------------|
| **k8s-ops/** | Core kubectl operations - deployments, rollouts, logs, exec, scaling, rollback |
| **k8s-debug/** | Troubleshooting workflows - CrashLoopBackOff, ImagePullBackOff, networking, volumes |
| **k8s-manifests/** | YAML templates - deployments, services, ingress, configmaps, statefulsets, HPA |
| **k8s-deploy-auto/** | CI/CD automation - GitHub Actions, GitLab CI, ArgoCD, Kustomize, canary deploys |
| **k9s-ui/** | k9s terminal UI navigation - shortcuts, commands, filtering, plugins |

## When to Use

- **k8s-ops**: Deploying manifests, checking rollout status, viewing logs, managing namespaces
- **k8s-debug**: Pod failures, networking issues, resource problems, CrashLoopBackOff
- **k8s-manifests**: Creating new k8s resources, scaffolding applications, YAML templates
- **k8s-deploy-auto**: CI/CD pipelines, GitOps workflows, automated deployments
- **k9s-ui**: Interactive cluster management with k9s terminal UI

## Quick Reference

```bash
# Deploy and monitor
kubectl apply -f manifest.yaml -n production
kubectl rollout status deployment/app -n production --timeout=300s

# Debug pod issues
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous

# Generate manifests
kubectl create deployment app --image=nginx --dry-run=client -o yaml

# k9s navigation
k9s -n production          # Start in namespace
:deploy                    # Jump to deployments
l                          # View pod logs
s                          # Shell into pod
```
