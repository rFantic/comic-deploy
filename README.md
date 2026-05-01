# Comic Generator — Deploy

Kubernetes manifests for staging the comic-generator project on a local [Kind](https://kind.sigs.k8s.io/) cluster with [Istio](https://istio.io/) service mesh and [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) for external access.

## Architecture

```
Internet → Cloudflare Edge → cloudflared (in-cluster) → Istio IngressGateway
                                                            ├─ /api/*  → backend
                                                            ├─ /health → backend
                                                            └─ /*      → frontend
```

Local dev (no tunnel):

```
Browser → localhost:30080 → Kind NodePort → Istio IngressGateway
                                                      ├─ /api/*  → backend
                                                      └─ /*      → frontend
```

## Prerequisites

- Docker
- Kind
- kubectl
- istioctl (Istio 1.28+)
- Firefox browser with active Gemini session (for cookie extraction)

## Quick Start

```bash
# 1. Create Kind cluster (includes Firefox profile mount)
kind create cluster --config kind-config.yaml

# 2. Rename context
kubectl config rename-context kind-kind comic-cluster

# 3. Install Istio with ingress gateway
istioctl install --set profile=minimal \
  --set components.ingressGateways[0].enabled=true \
  --set components.ingressGateways[0].name=istio-ingressgateway -y

# 4. Patch gateway to use NodePort 30080
kubectl patch svc istio-ingressgateway -n istio-system -p '{
  "spec": {
    "type": "NodePort",
    "ports": [{"port": 80, "targetPort": 8080, "nodePort": 30080, "name": "http2"}]
  }
}'

# 5. Create secrets file (see .env.example)
cp .env.example k8s/base/.env.shared
# Edit .env.shared with real values

# 6. Deploy everything
kubectl apply -k k8s/base

# 7. Build and load images
docker build -t docker-backend:latest -f comic-backend/develop/infra/docker/Dockerfile comic-backend/develop/
docker build -t docker-frontend:latest comic-frontend/develop/
kind load docker-image docker-backend:latest docker-frontend:latest --name kind

# 8. Restart pods to pick up new images
kubectl rollout restart deployment/backend deployment/worker deployment/frontend -n comic-prod
```

## Access

- **Local:** `http://127.0.0.1:30080`
- **External:** `https://comic.apl.io.vn` (requires Cloudflare Tunnel token)

## Firefox Cookie Mount

The backend and worker need Gemini cookies to call the Gemini API. Your Firefox profile is mounted into the Kind node via `kind-config.yaml` `extraMounts`, then mounted as a `hostPath` volume in backend and worker pods.

If your Firefox profile path changes, update:
1. `kind-config.yaml` → `extraMounts.hostPath`
2. `k8s/base/backend.yaml` → `volumeMounts.mountPath` + `FIREFOX_COOKIE_PATH` env var
3. `k8s/base/worker.yaml` → same as backend

## Environment Variables

See `.env.example` for all required secrets. Copy to `k8s/base/.env.shared`:

```bash
cp .env.example k8s/base/.env.shared
# Fill in real values
```

The kustomization uses `secretGenerator` with `disableNameSuffixHash: true` so the secret is named `comic-secrets` (not `comic-secrets-XXXX`).

## Git Workflow

This repo uses bare git + worktrees:

| Worktree | Branch  | Purpose        |
|----------|---------|----------------|
| `main/`  | main    | Stable/release |
| `develop/`| develop | Working branch |

## Components

| Component   | Manifest              | Description                       |
|-------------|-----------------------|-----------------------------------|
| PostgreSQL  | `postgres.yaml`       | StatefulSet + PVC                 |
| Redis       | `redis.yaml`          | Single-instance Deployment        |
| MinIO       | `minio.yaml`          | Object storage, ClusterIP only    |
| Backend     | `backend.yaml`        | FastAPI app, port 8000            |
| Worker      | `worker.yaml`         | RQ worker (same image, different CMD) |
| Frontend    | `frontend.yaml`       | Vue 3 SPA, port 3000              |
| Istio       | `istio.yaml`          | Gateway + VirtualServices         |
| Cloudflared | `cloudflared.yaml`    | Cloudflare Tunnel (optional)      |

## Domain

- `https://comic.apl.io.vn` — routed via Cloudflare Tunnel (requires `TUNNEL_TOKEN` in secrets)
- `http://127.0.0.1:30080` — local access via Kind NodePort (always available)
