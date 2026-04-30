# Comic Deploy

Kubernetes deployment configurations for the Comic Generator application.

## Overview

This repository contains Kubernetes manifests, Istio configurations, and deployment scripts for deploying the Comic Generator application to a Kubernetes cluster.

## Components

- **Kubernetes manifests** - Deployments, Services, ConfigMaps
- **Istio resources** - Virtual Services for traffic management
- **Kind cluster** - Local development cluster configuration
- **Makefile** - Deployment automation scripts

## Prerequisites

- **kubectl** - Kubernetes CLI
- **kind** - Kubernetes in Docker (for local development)
- **istioctl** - Istio CLI
- **docker** - Container runtime

## Quick Start

### Local Development with Kind

```bash
# Create Kind cluster with Istio
make reset-cluster

# Build and load Docker images
make build-images
make load-images

# Deploy application
make deploy-blue

# Access services
make port-forward-all
```

Services will be available at:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000

## Deployment Commands

### Cluster Management

```bash
make build-images          # Build backend/frontend Docker images
make load-images           # Load images into Kind cluster
make create-namespace      # Create namespace with Istio injection
make reset-cluster         # Delete and recreate Kind cluster
```

### Deployments

```bash
make deploy-blue           # Deploy v1 (Blue version)
make deploy-green          # Deploy v2 (Green version)
```

### Traffic Management

```bash
make traffic-blue          # Route 100% traffic to Blue
make traffic-canary        # Route 90% Blue / 10% Green (canary)
make traffic-canary-reverse  # Route 10% Blue / 90% Green
make traffic-green         # Route 100% traffic to Green
```

### Service Access

```bash
make port-forward-frontend   # Access frontend at http://localhost:3000
make port-forward-backend    # Access backend at http://localhost:8000
make port-forward-all        # Access all services
make stop-port-forwards       # Stop all active port forwards
make show-urls               # Show all access URLs
```

### Monitoring

```bash
make install-monitoring      # Install Istio addons (Prometheus, Kiali, Grafana)
make open-kiali              # Open Kiali dashboard
make open-grafana            # Open Grafana dashboard
make open-prometheus         # Open Prometheus dashboard
make port-forward-monitoring # Forward monitoring services
```

### Maintenance

```bash
make logs               # Show logs from all pods
make status             # Check pod status in comic-prod namespace
make status-all         # Check status across all namespaces
make clean              # Delete K8s resources
```

## Architecture

### Deployment Strategy

The application uses a **blue-green deployment** strategy with Istio traffic management:
- **Blue deployment** - Stable production version (v1)
- **Green deployment** - New version (v2)
- **Canary deployments** - Gradual traffic split (90/10 or 10/90)

### Components

- **Backend** - FastAPI service (Python)
- **Frontend** - React application (Node.js/Express)
- **Database** - PostgreSQL
- **Istio** - Service mesh for traffic management and observability

## Kubernetes Resources

### Namespace

All resources are deployed to the `comic-prod` namespace with Istio sidecar injection enabled.

### Services

- `backend` - Backend API service (port 8000)
- `frontend` - Frontend web service (port 3000)
- `backend-blue` / `backend-green` - Version-specific backend services
- `frontend-blue` / `frontend-green` - Version-specific frontend services

### Virtual Services

- `vs-blue.yaml` - Route all traffic to blue version
- `vs-green.yaml` - Route all traffic to green version
- `vs-canary.yaml` - Route 90% to blue, 10% to green
- `vs-canary-reverse.yaml` - Route 10% to blue, 90% to green

## Configuration

### Environment Variables

Application configuration is managed via ConfigMaps and Secrets (see `k8s/` directory).

### Image Tags

Update image tags in `k8s/backend.yaml` and `k8s/frontend.yaml` before deploying:
```yaml
image: comic-backend:latest
image: comic-frontend:latest
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n comic-prod

# View pod logs
kubectl logs -l app=backend -n comic-prod --all-containers
kubectl logs -l app=frontend -n comic-prod --all-containers
```

### Traffic Not Routing

```bash
# Check Istio virtual services
kubectl get virtualservices -n comic-prod

# View Istio configuration
istioctl proxy-status
```

### Image Pull Errors

```bash
# Ensure images are loaded into Kind cluster
make load-images

# Verify images exist
docker images | grep comic
```

## Monitoring

After installing monitoring addons:

- **Grafana**: http://localhost:23000 (after port-forward)
- **Kiali**: http://localhost:20001 (after port-forward)
- **Prometheus**: http://localhost:9090 (after port-forward)

## Project Structure

```
comic-deploy/
├── k8s/                     # Kubernetes manifests
│   ├── backend.yaml         # Backend deployment
│   ├── frontend.yaml        # Frontend deployment
│   ├── database.yaml        # PostgreSQL deployment
│   ├── kustomization.yaml   # Kustomize configuration
│   └── istio-resources.yaml # Istio gateway/route
├── vs-blue.yaml             # Route all traffic to blue
├── vs-green.yaml            # Route all traffic to green
├── vs-canary.yaml           # Canary deployment (90/10)
├── vs-canary-reverse.yaml   # Reverse canary (10/90)
├── Makefile                 # Deployment automation
├── kind-config.yaml         # Kind cluster configuration
└── nginx.example.conf       # Nginx reverse proxy config
```

## License

See LICENSE file for details.
