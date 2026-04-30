# Kubernetes + Istio Makefile for Comic Generator

.PHONY: help build-images load-images create-namespace deploy-blue deploy-green traffic-blue traffic-canary traffic-canary-reverse traffic-green logs status clean install-monitoring open-kiali open-grafana open-prometheus reset-cluster port-forward-frontend port-forward-backend port-forward-all port-forward-monitoring stop-port-forwards show-urls

help:
	@echo "Available commands:"
	@echo "  make build-images      - Build backend/frontend Docker images"
	@echo "  make load-images       - Load images into Kind cluster"
	@echo "  make create-namespace  - Create comic-prod namespace with Istio injection"
	@echo "  make deploy-blue       - Deploy Blue (v1) version"
	@echo "  make deploy-green      - Deploy Green (v2) version"
	@echo "  make traffic-blue      - Route 100% traffic to Blue"
	@echo "  make traffic-canary    - Route 90% Blue / 10% Green"
	@echo "  make traffic-canary-reverse - Route 10% Blue / 90% Green"
	@echo "  make traffic-green     - Route 100% traffic to Green"
	@echo "  make logs              - Show logs from all pods"
	@echo "  make status            - Check pod status"
	@echo "  make status-all        - Check status across all namespaces"
	@echo "  make install-monitoring - Install Istio addons (Prometheus, Kiali, Grafana)"
	@echo "  make port-forward-frontend  - Access frontend at http://localhost:3000"
	@echo "  make port-forward-backend   - Access backend API at http://localhost:8000"
	@echo "  make port-forward-all      - Access all services (frontend, backend, monitoring)"
	@echo "  make port-forward-monitoring - Access monitoring dashboards"
	@echo "  make stop-port-forwards     - Stop all active port forwards"
	@echo "  make clean             - Delete K8s resources"
	@echo "  make reset-cluster     - Delete and recreate Kind cluster"

build-images:
	docker build -t comic-generator-backend:latest ./backend
	docker build -t comic-generator-frontend:latest ./frontend

load-images:
	@echo "Loading images into Kind cluster..."
	kind load docker-image comic-generator-backend:latest --name comic-cluster
	kind load docker-image comic-generator-frontend:latest --name comic-cluster
	@echo "Images loaded successfully"

create-namespace:
	@echo "Creating namespace comic-prod with Istio injection..."
	kubectl create namespace comic-prod || echo "Namespace already exists"
	kubectl label namespace comic-prod istio-injection=enabled || true
	@echo "Namespace ready"

deploy-blue: create-namespace
	@echo "Deploying Blue (v1) version..."
	kubectl apply -k k8s
	kubectl apply -f k8s/vs-blue.yaml
	@echo "Blue deployment complete"

deploy-green: create-namespace
	@echo "Deploying Green (v2) version..."
	kubectl apply -k k8s
	kubectl apply -f k8s/vs-green.yaml
	@echo "Green deployment complete"

traffic-blue:
	@echo "Routing 100% traffic to Blue..."
	kubectl apply -f k8s/vs-blue.yaml

traffic-canary:
	@echo "Routing 90% traffic to Blue, 10% to Green..."
	kubectl apply -f k8s/vs-canary.yaml

traffic-canary-reverse:
	@echo "Routing 10% traffic to Blue, 90% to Green..."
	kubectl apply -f k8s/vs-canary-reverse.yaml

traffic-green:
	@echo "Routing 100% traffic to Green..."
	kubectl apply -f k8s/vs-green.yaml

logs:
	kubectl logs -l app=backend -n comic-prod --all-containers
	kubectl logs -l app=frontend -n comic-prod --all-containers

status:
	@echo "=== Comic Production (comic-prod) ==="
	kubectl get pods -n comic-prod

status-all:
	@echo "=== All Pods Across Namespaces ==="
	kubectl get pods -A

install-monitoring:
	@echo "Installing Istio addons for monitoring..."
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/addons/prometheus.yaml
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/addons/kiali.yaml
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/addons/grafana.yaml
	@echo "Monitoring addons installed"
	@echo "Waiting for pods to be ready..."
	sleep 15
	kubectl get pods -n istio-system

reset-cluster:
	@echo "Deleting Kind cluster..."
	kind delete cluster --name comic-cluster
	@echo "Creating new Kind cluster..."
	kind create cluster --config kind-config.yaml --name comic-cluster
	@echo "Installing Istio..."
	istioctl install --set profile=demo -y
	@echo "Creating namespace..."
	kubectl create namespace comic-prod
	kubectl label namespace comic-prod istio-injection=enabled
	@echo "Applying all manifests..."
	kubectl apply -k k8s
	kubectl apply -f k8s/vs-blue.yaml
	@echo "Cluster reset complete. Use 'make install-monitoring' to add observability"

clean:
	kubectl delete namespace comic-prod

# Port forwarding targets for accessing services
port-forward-frontend:
	@( \
	kubectl port-forward -n comic-prod svc/frontend 3000:3000 & \
	kubectl port-forward -n comic-prod svc/frontend-blue 3001:3001 & \
	kubectl port-forward -n comic-prod svc/frontend-green 3002:3002 & \
		wait \
	)

port-forward-backend:
	@echo "Forwarding backend API to http://localhost:8000"
	kubectl port-forward -n comic-prod svc/backend 8000:8000

port-forward-monitoring:
	@echo "Forwarding monitoring services (Ctrl+C to stop all):"
	@echo "  Grafana:    http://localhost:3000"
	@echo "  Kiali:      http://localhost:20001"
	@echo "  Prometheus: http://localhost:9090"
	@( \
		kubectl port-forward -n istio-system svc/grafana 23000:3000 & \
		kubectl port-forward -n istio-system svc/kiali 20001:20001 & \
		kubectl port-forward -n istio-system svc/prometheus 9090:9090 & \
		wait \
	)
