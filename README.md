# Mogambo Microservices Platform

Enterprise-grade microservices commerce platform running on AWS EKS with Terraform, Helm, ArgoCD GitOps, and CI/CD pipelines.

This README is a full technical handbook for the current repository state.

## 1) Executive Summary

Mogambo is a multi-service platform composed of:

- front-end (Node.js/Express): UI + API gateway aggregation
- catalogue (Go): product catalogue and tags
- carts (Spring Boot): shopping cart domain
- carts-db (MongoDB StatefulSet): carts persistence
- catalogue-db (Amazon RDS MySQL): catalogue persistence

Deployment model:

- infrastructure provisioned by Terraform
- workloads deployed by ArgoCD (App of Apps) from Helm charts
- CI pipelines build, test, scan, push images, and auto-bump Helm image tags on dev

## 2) Current Runtime Architecture

```text
Internet
      |
ALB Ingress (AWS Load Balancer Controller)
      |
front-end service (port 80 -> container 8079)
      |-- /catalogue          -> catalogue service (port 80)
      |-- /carts              -> carts service (port 8080)
      |-- /catalogue/images/* -> front-end redirect to CloudFront

catalogue (Go)
      -> RDS MySQL 8.4 (private)

carts (Spring Boot)
      -> carts-db MongoDB StatefulSet (in-cluster)

Static/media delivery
      CloudFront -> private S3 bucket via OAC
```

## 3) Service Contract Matrix

| Service | Tech | Internal Port | Health Endpoint | Metrics Endpoint | Data Store |
|---|---|---:|---|---|---|
| front-end | Node.js (Express) | 8079 | /healthz | /metrics (currently returns 500) | Session memory or Redis (optional) |
| catalogue | Go (go-kit) | 80 | /health | /metrics (working) | RDS MySQL |
| carts | Java (Spring Boot 3) | 8080 | /health | not exposed in current runtime | MongoDB |
| carts-db | MongoDB 4.4 | 27017 | TCP probe | n/a | PVC (gp2) |
| catalogue-db | RDS MySQL 8.4 | 3306 | managed service | n/a | AWS RDS |

## 4) Repository Map (Audited)

Total tracked files (excluding .git): 408

Top-level distribution:

- .github: 5
- ansible: 11
- deploy: 57
- docs: 4
- infra: 34
- scripts: 3
- src: 292

### 4.1 CI/CD (.github/workflows)

- carts-ci.yml: Java build/test, security scan, Sonar (optional), Docker build/push, Helm tag update
- catalogue-ci.yml: Go build/test, scan, Sonar (optional), Docker build/push, Helm tag update
- frontend-ci.yml: Node build/test, scan, Sonar (optional), Docker build/push, Helm tag update
- infra.yml: manual Terraform plan/apply/destroy/outputs for dev environment
- README.md: workflow-level behavior documentation

### 4.2 Ansible (ansible)

Purpose: SonarQube provisioning on Amazon Linux 2023.

Key files:

- ansible.cfg: local Ansible runtime defaults
- inventory/hosts.ini: target host inventory
- group_vars/all.yml: role variables and environment overrides
- playbooks/setup_sonarqube.yml: playbook entrypoint
- roles/sonarqube/tasks/main.yml: provisioning workflow
- roles/sonarqube/templates/sonar.properties.j2: SonarQube config
- roles/sonarqube/templates/sonarqube.service.j2: systemd unit template

### 4.3 GitOps and Deploy (deploy)

ArgoCD apps:

- deploy/argocd/root-app.yaml: app-of-apps root
- deploy/argocd/apps/*.yaml: per-component applications
- monitoring additions:
      - monitoring-crds.yaml
      - monitoring-stack.yaml
      - monitoring-targets.yaml

Helm charts:

- front-end, catalogue, catalogue-db, carts, carts-db
- each chart contains Chart.yaml, values.yaml, templates, helpers

Raw Kubernetes manifests:

- deploy/k8s/* mirrors baseline manifests
- deploy/k8s/monitoring/servicemonitor-catalogue.yaml adds catalogue scrape target

### 4.4 Infrastructure as Code (infra)

Terraform environment:

- infra/terraform/environments/dev/main.tf: module composition
- variables.tf: defaults (VPC, EKS, DB, ECR, S3, Sonar EC2)
- outputs.tf: consolidated outputs used by operations
- backend.tf/providers.tf/versions.tf: backend/provider/version controls

Modules:

- vpc: VPC, subnets, IGW, NAT, routing
- sg: ALB/EKS/RDS/Sonar SGs and rules
- eks: cluster + managed nodegroup
- iam: cluster/node IAM roles and policy attachments
- rds: MySQL DB instance and subnet group
- ecr: repositories for front-end/catalogue/carts
- s3: S3 bucket + CloudFront + OAC + policy
- ec2: SonarQube instance

Note:

- infra/terraform/environments/dev/.terraform/* contains generated local artifacts/provider binaries and should be treated as environment-generated state, not hand-authored platform code.

### 4.5 Operations Scripts (scripts)

- bootstrap.sh: end-to-end cluster bootstrap for GitOps deployment
      - validates tooling and env
      - configures kubeconfig
      - creates namespaces/secrets
      - optional EBS CSI add-on
      - optional ALB controller install/reconcile
      - enforces ALB IAM extras (including SetRulePriorities)
      - applies root Argo app and waits for apps
      - normalizes catalogue DSN with allowNativePasswords=true
- cleanup.sh: safe pre-destroy cleanup workflow before terraform destroy
      - supports dry-run preview mode
      - supports force mode via --force and -y
      - removes ArgoCD applications and Helm releases
      - deletes load balancers, ALB IAM role/policies, and optional OIDC provider
      - removes application namespaces with timeout/finalizer handling
- install-sonarqube-al2023.sh: standalone SonarQube installer for AL2023 EC2
- .env: runtime secret source for bootstrap

### 4.6 Application Source (src)

#### carts (Java/Spring)

Important files:

- CartApplication.java: service bootstrap
- controllers/CartsController.java: cart CRUD + merge endpoints
- controllers/ItemsController.java: cart item CRUD/patch endpoints
- controllers/HealthCheckController.java: app/db health response
- middleware/HTTPMonitoringInterceptor.java: histogram instrumentation (request duration labels)
- repositories/* + cart/* + item/* + entities/*: domain and persistence model
- application.properties: runtime config
- pom.xml: build/dependency definition
- test/* and src/test/*: unit/integration and containerized tests

#### catalogue (Go)

Important files:

- cmd/cataloguesvc/main.go: process bootstrap, DB connect, middleware, transport
- service.go: business logic and SQL reads
- transport.go: HTTP routing, health and /metrics endpoint
- endpoints.go: endpoint bindings and DTOs
- logging.go: method-level structured logging middleware
- data/dump.sql: schema/seed data
- images/*: local static product image assets
- test/* + service_test.go: unit/container tests

#### front-end (Node.js)

Important files:

- server.js: app bootstrap and middleware wiring
- api/catalogue/index.js: catalogue proxy and /catalogue/images redirect logic
- api/cart/index.js: cart orchestration endpoint layer
- api/metrics/index.js: Prometheus endpoint middleware
- api/endpoints.js: service endpoint resolution (including cloudfront image base)
- helpers/index.js: HTTP proxy helper and session middleware
- public/*: UI HTML, JS, CSS, fonts, images
- test/*: API and e2e test suite
- package.json: dependency and scripts definition

#### Local compose

- src/docker-compose.yml: local multi-service stack (front-end, catalogue, carts + DBs)

## 5) Network and Traffic Routing Details

Ingress behavior (front-end chart):

- /catalogue/images -> front-end service (redirects to CloudFront)
- /catalogue -> catalogue
- /carts -> carts
- / -> front-end

This routing is critical for image rendering and must keep /catalogue/images above /catalogue.

## 6) Security and Access Controls

- IRSA used for Kubernetes controllers requiring AWS APIs
- ALB controller role includes additional runtime actions needed in this environment
- RDS private access via VPC and SG rules
- S3 bucket kept private with CloudFront OAC
- Terraform state uses S3 backend with DynamoDB locking

## 7) Observability and Monitoring

GitOps monitoring apps:

- monitoring-crds (Prometheus Operator CRDs)
- monitoring-stack (kube-prometheus-stack)
- monitoring-targets (ServiceMonitors and targets)

Currently implemented:

- Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics
- ServiceMonitor for catalogue (/metrics)

Current service readiness for scraping:

- catalogue: up
- front-end: /metrics returns 500 and needs app fix
- carts: no active metrics endpoint exposed

Additional operations docs:

- docs/monitoring.md
- docs/bootstrap-guide.md
- docs/cleanup-guide.md
- docs/bootstrap-vs-cleanup.md

## 8) CI/CD and Release Flow

Per service pipeline pattern:

1. detect path changes
2. build/test + security checks + optional Sonar
3. build and push ECR image on push to dev
4. auto-update matching Helm values image tag with short commit SHA

Infra pipeline supports manual Terraform operations.

## 9) End-to-End Deployment Workflow

### 9.1 Provision infra (dev)

```bash
cd infra/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 9.2 Bootstrap cluster and GitOps

```bash
cd scripts
./bootstrap.sh --env-file .env
```

### 9.3 Validate runtime

```bash
kubectl -n argocd get applications
kubectl -n mogambo get pods,svc,ingress
kubectl -n monitoring get pods
```

### 9.4 Pre-destroy cleanup (recommended)

```bash
cd scripts
./cleanup.sh --dry-run
./cleanup.sh -y --skip-oidc
```

### 9.5 Destroy infra (dev)

```bash
cd infra/terraform/environments/dev
terraform destroy
```

## 10) Local Development Workflow

```bash
cd src
docker compose up -d
```

Local ports:

- front-end: 8079
- catalogue: 8081
- carts: 8082
- mysql: 3306
- mongo: 27017

## 11) Troubleshooting Playbook

### ALB/Ingress issues

- verify aws-load-balancer-controller is running
- verify ingress class alb exists
- verify controller IAM role has required ELBv2 actions including SetRulePriorities

### carts-db OutOfSync in ArgoCD

- if caused by immutable StatefulSet fields (volumeClaimTemplates), recreate StatefulSet while retaining PVC

### catalogue DB auth failures

- ensure DSN compatibility flags are set for legacy MySQL driver behavior
- confirm DB user plugin compatibility

### monitoring stack OutOfSync due CRDs

- manage Prometheus CRDs separately via monitoring-crds app
- keep monitoring-stack set to not install CRDs directly

## 12) Known Drift/Legacy Notes

- upstream service READMEs under src/* include legacy instructions (Ubuntu 16 era) and are not the authoritative deployment source for this platform
- root deployment truth is Terraform + Helm + ArgoCD in this repository

## 13) Project Standards and Conventions

- GitOps source of truth: deploy/argocd + deploy/helm
- environment defaults: infra/terraform/environments/dev
- image tags in Helm are commit-sha based and CI-managed
- scripts/bootstrap.sh is the preferred operational bootstrap entrypoint
- scripts/cleanup.sh is the preferred teardown entrypoint before terraform destroy

## 14) Complete File Manifest (Operationally Relevant)

The repository includes a large static UI asset set and legacy upstream artifacts.
Operationally relevant areas are fully mapped in sections 4.1 to 4.6.

For complete raw file inventory (all 408 tracked files), run:

```bash
git ls-files | sort
```
