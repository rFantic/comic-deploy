# Comic Generator — Deploy

Kubernetes manifests for staging the comic-generator project on a local [Kind](https://kind.sigs.k8s.io/) cluster with [Istio](https://istio.io/) service mesh and [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) for external access.

## Architecture

```
Internet → Cloudflare Edge → cloudflared (in-cluster) → Istio IngressGateway
                                                            ├─ /api/*  → backend
                                                            ├─ /health → backend
                                                            └─ /*      → frontend
```

## Prerequisites

- Docker
- Kind
- kubectl
- istioctl (Istio 1.28+)
- Local image registry running on port 5000

## Quick Start

```bash
# 1. Create Kind cluster
make cluster-create

# 2. Install Istio
make istio-install

# 3. Create namespace with secrets
kubectl apply -k k8s/base  # namespace first
kubectl create secret generic comic-secrets --from-env-file=.env -n comic-prod

# 4. Build and push backend image
make build push

# 5. Deploy everything
make deploy

# 6. Check status
make status
```

## Environment Variables

See `.env.example` for all required secrets. Create `.env` from the example and fill in values:

```bash
cp .env.example .env
kubectl create secret generic comic-secrets --from-env-file=.env -n comic-prod
```

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
| Frontend    | `frontend.yaml`       | Placeholder, port 3000            |
| Istio       | `istio.yaml`          | Gateway + VirtualService (v1beta1) |
| Cloudflared | `cloudflared.yaml`    | 2 replicas, token from Secret     |

## Domain

`https://comic.apl.io.vn/` — routed via Cloudflare Tunnel (configured at Cloudflare dashboard).
