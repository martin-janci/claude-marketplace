# Kubernetes Toolkit

Comprehensive Kubernetes operations toolkit with skills for cluster management, debugging, manifest generation, deployment automation, k9s terminal UI, and SSH remote access.

## Skills

| Skill | Description |
|-------|-------------|
| **k8s-ops/** | Core kubectl operations - deployments, rollouts, logs, exec, scaling, rollback |
| **k8s-debug/** | Troubleshooting workflows - CrashLoopBackOff, ImagePullBackOff, networking, volumes |
| **k8s-manifests/** | YAML templates - deployments, services, ingress, configmaps, statefulsets, HPA |
| **k8s-deploy-auto/** | CI/CD automation - GitHub Actions, GitLab CI, ArgoCD, Kustomize, canary deploys |
| **k9s-ui/** | k9s terminal UI navigation - shortcuts, commands, filtering, plugins |
| **ssh-ops/** | SSH tunneling, remote kubectl/k9s, bastion/jump hosts, port forwarding |

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/tunnel.sh` | SSH tunnel manager - start/stop/status persistent tunnels |
| `scripts/remote-k8s-check.sh` | Remote k8s health check via SSH |

## When to Use

- **k8s-ops**: Deploying manifests, checking rollout status, viewing logs, managing namespaces
- **k8s-debug**: Pod failures, networking issues, resource problems, CrashLoopBackOff
- **k8s-manifests**: Creating new k8s resources, scaffolding applications, YAML templates
- **k8s-deploy-auto**: CI/CD pipelines, GitOps workflows, automated deployments
- **k9s-ui**: Interactive cluster management with k9s terminal UI
- **ssh-ops**: Remote cluster access through bastion, SSH tunnels, remote kubectl/k9s

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

# Remote access via SSH
ssh -J user@bastion admin@k8s-master "kubectl get pods"
ssh -t user@k8s-master "k9s -n production"
ssh -L 6443:kubernetes:443 user@bastion  # Tunnel to k8s API
```
