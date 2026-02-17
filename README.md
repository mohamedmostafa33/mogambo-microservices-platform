# Mogambo Microservices Platform

> Enterprise-grade microservices e-commerce platform deployed on AWS EKS.

## Architecture

```
                         ┌──────────────┐
                         │   Ingress    │
                         │   (ALB)      │
                         └──────┬───────┘
                                │
                         ┌──────▼───────┐
                         │  Front-end   │
                         │  (Node.js)   │
                         │  Port: 8079  │
                         └──┬───────┬───┘
                            │       │
                 ┌──────────▼─┐   ┌─▼──────────┐
                 │ Catalogue  │   │   Carts     │
                 │   (Go)     │   │(Spring Boot)│
                 │ Port: 80   │   │  Port: 80   │
                 └─────┬──────┘   └──────┬──────┘
                       │                 │
                 ┌─────▼──────┐   ┌──────▼──────┐
                 │   MySQL    │   │  MongoDB    │
                 │  (RDS)     │   │(DocumentDB) │
                 └────────────┘   └─────────────┘
```

## Repository Structure

```
mogambo-microservices-platform/
│
├── src/                        # Application source code
│   ├── front-end/              # Node.js/Express API Gateway + UI
│   ├── catalogue/              # Go product catalogue service
│   └── carts/                  # Java/Spring Boot cart service
│
├── deploy/                     # Deployment configurations
│   ├── helm/                   # Helm charts
│   │   └── charts/
│   │       ├── front-end/
│   │       ├── catalogue/
│   │       └── carts/
│   └── argocd/                 # ArgoCD application manifests
│       ├── apps/
│       └── projects/
│
├── infra/                      # Infrastructure as Code
│   └── terraform/
│       ├── modules/            # Reusable Terraform modules
│       └── environments/       # Per-environment configs
│           ├── dev/
│           ├── staging/
│           └── prod/
│
├── .github/                    # CI/CD
│   └── workflows/              # GitHub Actions pipelines
│
├── docs/                       # Documentation
└── scripts/                    # Shared utility scripts
```

## Services

| Service | Language | Database | Port |
|---------|----------|----------|------|
| Front-end | Node.js 20 | Redis (sessions) | 8079 |
| Catalogue | Go | MySQL 5.7 | 80 |
| Carts | Java 21 (Spring Boot 3) | MongoDB 4.4 | 80 |

## Tech Stack

- **Container Orchestration**: Amazon EKS
- **CI/CD**: GitHub Actions + ArgoCD (GitOps)
- **IaC**: Terraform
- **Package Manager**: Helm
- **Databases**: Amazon RDS (MySQL), Amazon DocumentDB, ElastiCache (Redis)
- **Networking**: ALB Ingress Controller, AWS VPC
- **Observability**: Prometheus, Grafana, CloudWatch
- **Security**: IRSA, Secrets Manager, Network Policies

## Getting Started

### Local Development (Docker Compose)

```bash
cd src/
docker-compose up -d
```

### Deploy to EKS

```bash
# 1. Provision infrastructure
cd infra/terraform/environments/dev
terraform init && terraform apply

# 2. Deploy services
cd deploy/helm/charts
helm install front-end ./front-end
helm install catalogue ./catalogue
helm install carts ./carts
```

## License

MIT