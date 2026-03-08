# Mogambo Microservices Platform -- Infrastructure

This document describes the cloud infrastructure provisioned and managed via Terraform
for the Mogambo Microservices Platform. All resources target **AWS** in the `us-east-1` region.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Directory Structure](#directory-structure)
3. [Prerequisites](#prerequisites)
4. [Terraform Backend](#terraform-backend)
5. [Modules](#modules)
   - [VPC](#vpc-module)
   - [Security Groups](#security-groups-module)
   - [RDS](#rds-module)
   - [ECR](#ecr-module)
   - [S3 and CloudFront](#s3-and-cloudfront-module)
   - [IAM](#iam-module)
   - [EKS](#eks-module)
6. [Environment Configuration (dev)](#environment-configuration-dev)
7. [Module Dependency Graph](#module-dependency-graph)
8. [Security Considerations](#security-considerations)
9. [Operational Procedures](#operational-procedures)

---

## Architecture Overview

The platform runs three microservices on Amazon EKS:

| Service     | Runtime          | Database           | Port |
|-------------|------------------|--------------------|------|
| front-end   | Node.js 20       | --                 | 8079 |
| catalogue   | Go (Go-kit)      | MySQL 8.4 (RDS)    | 80   |
| carts       | Java 21 (Spring) | MongoDB (in-cluster) | 80 |

Static and media assets (product images, UI resources) are stored in S3 and served
through a CloudFront distribution. Container images are stored in Amazon ECR with
immutable tags and scan-on-push enabled.

### High-Level Resource Map

```
Internet
   |
CloudFront (static/media) --- S3 Bucket (private, OAC)
   |
ALB (public subnets)
   |
EKS Cluster (private subnets)
   |--- front-end pods
   |--- catalogue pods ---> RDS MySQL (private subnets)
   |--- carts pods -------> MongoDB StatefulSet (in-cluster)
   |
NAT Gateway (public subnet) ---> Internet (outbound only)
```

---

## Directory Structure

```
infra/
  terraform/
    environments/
      dev/                    # Dev environment root configuration
        backend.tf            # S3 remote state backend
        main.tf               # Module composition
        outputs.tf            # Aggregated outputs
        providers.tf          # AWS provider configuration
        variables.tf          # Environment-specific variable defaults
        versions.tf           # Terraform and provider version constraints
      staging/                # Placeholder for staging environment
      prod/                   # Placeholder for production environment
    modules/
      vpc/                    # Networking: VPC, subnets, gateways, routing
      sg/                     # Security groups and firewall rules
      rds/                    # RDS MySQL instance for catalogue service
      ecr/                    # ECR repositories for container images
      s3/                     # S3 bucket + CloudFront CDN for static assets
      iam/                    # IAM roles and policies for EKS
      eks/                    # EKS cluster and managed node group
```

---

## Prerequisites

| Requirement           | Version / Detail                         |
|-----------------------|------------------------------------------|
| Terraform             | >= 1.0                                   |
| AWS Provider          | ~> 5.0                                   |
| AWS CLI               | v2 (configured with appropriate profile) |
| S3 Bucket (state)     | `mogambo-tfstate`                        |
| DynamoDB Table (lock) | `mogambo-tfstate-lock`                   |
| IAM Permissions       | Sufficient to create VPC, EKS, RDS, ECR, S3, CloudFront, IAM resources |

The S3 bucket and DynamoDB table for remote state must be created manually
before running `terraform init` for the first time.

---

## Terraform Backend

| Parameter      | Value                  |
|----------------|------------------------|
| Type           | S3                     |
| Bucket         | `mogambo-tfstate`      |
| State Key      | `dev/terraform.tfstate`|
| Region         | `us-east-1`           |
| Lock Table     | `mogambo-tfstate-lock` |
| Encryption     | Enabled (SSE-S3)       |

Each environment (`dev`, `staging`, `prod`) uses a distinct state key prefix
to isolate state files.

---

## Modules

### VPC Module

**Path:** `modules/vpc/`

Provisions the networking foundation for all platform resources.

#### Resources Created

| Resource                  | Name / Tag                      | Description                                    |
|---------------------------|---------------------------------|------------------------------------------------|
| `aws_vpc`                 | `mogambo-vpc`                   | Primary VPC with DNS support enabled           |
| `aws_subnet` (public x2)  | `mogambo-public-subnet_1`, `_2` | Public subnets across 2 AZs, auto-assign public IP |
| `aws_subnet` (private x2) | `mogambo-private-subnet_1`, `_2`| Private subnets across 2 AZs                  |
| `aws_internet_gateway`    | `mogambo-internet-gateway`      | Internet gateway for public subnets            |
| `aws_eip`                 | `mogambo-eip`                   | Elastic IP for NAT gateway                     |
| `aws_nat_gateway`         | `mogambo-nat-gateway`           | NAT gateway in public subnet 1, depends on IGW |
| `aws_route_table` (public)| `mogambo-public-route-table`    | Routes 0.0.0.0/0 to Internet Gateway          |
| `aws_route_table` (private)| `mogambo-private-route-table`  | Routes 0.0.0.0/0 to NAT Gateway               |
| `aws_route_table_association` (x4) | --                     | Associates each subnet with its route table    |

#### Variables

| Name                          | Type   | Default (dev)   | Description                     |
|-------------------------------|--------|-----------------|---------------------------------|
| `vpc_cidr_block`              | string | `10.0.0.0/16`   | VPC CIDR                        |
| `public_subnet_cidr_block_1`  | string | `10.0.1.0/24`   | Public subnet 1 CIDR            |
| `public_subnet_cidr_block_2`  | string | `10.0.3.0/24`   | Public subnet 2 CIDR            |
| `private_subnet_cidr_block_1` | string | `10.0.2.0/24`   | Private subnet 1 CIDR           |
| `private_subnet_cidr_block_2` | string | `10.0.4.0/24`   | Private subnet 2 CIDR           |

#### Outputs

`vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `public_subnet_cidrs`,
`public_subnet_azs`, `private_subnet_ids`, `private_subnet_cidrs`,
`private_subnet_azs`, `internet_gateway_id`, `nat_gateway_id`,
`nat_gateway_eip`, `public_route_table_id`, `private_route_table_id`

---

### Security Groups Module

**Path:** `modules/sg/`

Defines all security groups and firewall rules across the platform.

#### Security Groups

| Security Group             | Tag Name                      | Purpose                           |
|----------------------------|-------------------------------|-----------------------------------|
| `mogambo_alb_sg`           | `mogambo-alb-sg`              | Application Load Balancer         |
| `mogambo_eks_node_group_sg`| `mogambo-eks-node-group-sg`   | EKS worker nodes                  |
| `mogambo_catalogue_db_sg`  | `mogambo-catalogue-db-sg`     | RDS MySQL for catalogue           |

#### Firewall Rules

| Rule                                | Type    | Port(s)       | Source / Destination               |
|--------------------------------------|---------|---------------|------------------------------------|
| HTTP to ALB                          | Ingress | 80            | `0.0.0.0/0`                        |
| HTTPS to ALB                         | Ingress | 443           | `0.0.0.0/0`                        |
| ALB to EKS nodes (HTTPS)             | Ingress | 443           | ALB SG                             |
| ALB to EKS nodes (NodePort)          | Ingress | 30000 - 32767 | ALB SG                             |
| Node-to-node (all traffic)           | Ingress | All           | EKS Node Group SG (self-referencing)|
| EKS nodes to RDS                     | Ingress | 3306          | EKS Node Group SG                  |
| ALB egress (all)                     | Egress  | All           | `0.0.0.0/0`                        |
| EKS nodes egress (all)               | Egress  | All           | `0.0.0.0/0`                        |
| Catalogue DB egress (all)            | Egress  | All           | `0.0.0.0/0`                        |

#### Variables

| Name     | Type   | Description |
|----------|--------|-------------|
| `vpc_id` | string | VPC ID      |

#### Outputs

`alb_sg_id`, `eks_node_group_sg_id`, `catalogue_db_sg_id`

---

### RDS Module

**Path:** `modules/rds/`

Provisions a MySQL RDS instance for the catalogue microservice.

#### Resources Created

| Resource               | Name / Identifier                  | Description                              |
|------------------------|------------------------------------|------------------------------------------|
| `aws_db_subnet_group`  | `mogambo-db-subnet-group`          | Subnet group spanning private subnets    |
| `aws_db_instance`       | `mogambo-catalogue-db-instance`   | MySQL 8.4.7, single-AZ, not public      |

#### Configuration (dev defaults)

| Parameter              | Value                           |
|------------------------|---------------------------------|
| Engine                 | MySQL 8.4.7                     |
| Instance Class         | `db.t4g.micro`                  |
| Storage                | 20 GB (auto-scales to 100 GB)   |
| Database Name          | `mogambo_catalogue_db`          |
| Username               | `mogambo_user`                  |
| Multi-AZ               | `false`                         |
| Publicly Accessible    | `false`                         |
| Final Snapshot          | Skipped (dev only)              |

#### Variables

| Name                     | Type         | Sensitive | Description                         |
|--------------------------|--------------|-----------|-------------------------------------|
| `db_subnet_group_name`   | string       | No        | Subnet group name                   |
| `db_subnet_ids`          | list(string) | No        | Subnet IDs for the group            |
| `db_engine`              | string       | No        | Database engine                     |
| `db_engine_version`      | string       | No        | Engine version                      |
| `db_instance_class`      | string       | No        | Instance class                      |
| `db_allocated_storage`   | number       | No        | Initial storage in GB               |
| `db_max_allocated_storage`| number      | No        | Maximum auto-scaled storage in GB   |
| `db_identifier`          | string       | No        | RDS instance identifier             |
| `db_name`                | string       | No        | Initial database name               |
| `db_username`            | string       | No        | Master username                     |
| `db_password`            | string       | Yes       | Master password                     |
| `db_security_group_ids`  | list(string) | No        | Security group IDs                  |

#### Outputs

`db_instance_id`, `db_instance_arn`, `db_endpoint`, `db_address`,
`db_port`, `db_identifier`, `db_name`, `db_subnet_group_name`,
`db_security_group_ids`

---

### ECR Module

**Path:** `modules/ecr/`

Creates Amazon ECR repositories for each microservice container image.

#### Repositories

| Repository Name   | Tag Mutability | Encryption | Scan on Push |
|-------------------|----------------|------------|--------------|
| `mogambo-frontend`  | IMMUTABLE    | KMS        | Enabled      |
| `mogambo-catalogue` | IMMUTABLE    | KMS        | Enabled      |
| `mogambo-cart`      | IMMUTABLE    | KMS        | Enabled      |

Immutable tags prevent image overwrites and enforce version traceability in
the deployment pipeline. KMS encryption secures images at rest. Scan-on-push
enables automated vulnerability detection on every image push.

#### Variables

| Name                       | Type   | Default (dev)       |
|----------------------------|--------|---------------------|
| `frontend_repository_name` | string | `mogambo-frontend`  |
| `catalogue_repository_name`| string | `mogambo-catalogue` |
| `cart_repository_name`     | string | `mogambo-cart`      |

#### Outputs (per repository)

`*_repository_name`, `*_repository_url`, `*_repository_arn`

---

### S3 and CloudFront Module

**Path:** `modules/s3/`

Provisions an S3 bucket for static and media asset storage with a CloudFront
CDN distribution for low-latency delivery.

#### Resources Created

| Resource                                    | Description                                                       |
|---------------------------------------------|-------------------------------------------------------------------|
| `aws_s3_bucket`                             | Private bucket for static/media assets                            |
| `aws_s3_bucket_public_access_block`         | Blocks all public access (ACLs and policies)                      |
| `aws_s3_bucket_versioning`                  | Enables object versioning                                         |
| `aws_s3_bucket_server_side_encryption_configuration` | AES-256 server-side encryption                          |
| `aws_s3_bucket_cors_configuration`          | Allows GET/HEAD from any origin (browser access)                  |
| `aws_cloudfront_origin_access_control`      | OAC with SigV4 signing for secure S3 access                      |
| `aws_cloudfront_distribution`               | CDN with HTTPS redirect, CachingOptimized policy, IPv6 enabled    |
| `aws_s3_bucket_policy`                      | Restricts S3 access exclusively to the CloudFront distribution    |

#### Asset Organization (recommended)

```
mogambo-platform-bucket/
  products/         # Product images from catalogue service
  ui/               # Front-end static images, banners, logos
  css/              # Stylesheets (optional offload)
  js/               # JavaScript bundles (optional offload)
```

#### Variables

| Name                     | Type   | Default (dev)             | Description                   |
|--------------------------|--------|---------------------------|-------------------------------|
| `bucket_name`            | string | `mogambo-platform-bucket` | S3 bucket name                |
| `environment`            | string | `dev`                     | Environment tag               |
| `cloudfront_price_class` | string | `PriceClass_100`          | Edge location coverage        |

#### Outputs

`mogambo_s3_bucket_name`, `mogambo_s3_bucket_arn`,
`mogambo_s3_bucket_regional_domain_name`, `mogambo_s3_bucket_region`,
`cloudfront_domain_name`, `cloudfront_distribution_id`,
`cloudfront_distribution_arn`

---

### IAM Module

**Path:** `modules/iam/`

Creates IAM roles and attaches AWS managed policies required by the EKS
control plane and worker nodes.

#### Roles

| Role Name                       | Trusted Service    | Purpose                    |
|---------------------------------|--------------------|----------------------------|
| `mogambo-eks-cluster-role`      | `eks.amazonaws.com`| EKS control plane          |
| `mogambo-eks-node-group-role`   | `ec2.amazonaws.com`| EKS managed node group     |

#### Policy Attachments

**Cluster Role:**

| Policy ARN                                         | Purpose                            |
|----------------------------------------------------|------------------------------------|
| `arn:aws:iam::aws:policy/AmazonEKSClusterPolicy`  | Core EKS cluster permissions       |
| `arn:aws:iam::aws:policy/AmazonEKSServicePolicy`  | EKS service-linked operations      |

**Node Group Role:**

| Policy ARN                                                  | Purpose                              |
|-------------------------------------------------------------|--------------------------------------|
| `arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy`        | EC2 permissions for worker nodes     |
| `arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy`             | VPC CNI plugin networking            |
| `arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly`| Pull images from ECR                 |

#### Variables

| Name                       | Type   | Default (dev)                  |
|----------------------------|--------|--------------------------------|
| `eks_role_name`            | string | `mogambo-eks-cluster-role`     |
| `eks_node_group_role_name` | string | `mogambo-eks-node-group-role`  |

#### Outputs

`eks_cluster_role_name`, `eks_cluster_role_arn`,
`eks_node_group_role_name`, `eks_node_group_role_arn`,
`eks_node_group_policies`, `eks_cluster_policies`

---

### EKS Module

**Path:** `modules/eks/`

Provisions the Amazon EKS cluster and a managed node group.

#### Resources Created

| Resource                | Name / Identifier          | Description                                              |
|-------------------------|----------------------------|----------------------------------------------------------|
| `aws_eks_cluster`       | `mogambo-eks-cluster`      | Kubernetes control plane, private + public API endpoints  |
| `aws_eks_node_group`    | `mogambo-eks-node-group`   | Managed node group with auto-scaling configuration       |

#### Configuration (dev defaults)

| Parameter            | Value            |
|----------------------|------------------|
| Kubernetes Version   | `1.31`           |
| Instance Type        | `t3.small`       |
| Desired Nodes        | 5                |
| Minimum Nodes        | 5                |
| Maximum Nodes        | 6                |
| Subnets              | Private only     |
| API Access           | Private + Public |

The node group has an explicit `depends_on` on the EKS cluster to ensure
correct creation ordering.

#### Variables

| Name                            | Type         | Description                             |
|---------------------------------|--------------|-----------------------------------------|
| `cluster_name`                  | string       | EKS cluster name                        |
| `kubernetes_version`            | string       | Kubernetes version                      |
| `eks_role_arn`                  | string       | IAM role ARN for the cluster            |
| `eks_subnet_ids`                | list(string) | Subnet IDs for cluster and nodes        |
| `eks_node_group_name`           | string       | Node group name                         |
| `eks_node_group_role_arn`       | string       | IAM role ARN for worker nodes           |
| `eks_node_group_instance_type`  | string       | EC2 instance type for nodes             |
| `desired_node_count`            | number       | Desired node count                      |
| `max_node_count`                | number       | Maximum node count                      |
| `min_node_count`                | number       | Minimum node count                      |

#### Outputs

`eks_cluster_name`, `eks_cluster_arn`, `eks_cluster_endpoint`,
`eks_node_group_name`, `eks_node_group_arn`

---

## Environment Configuration (dev)

The `environments/dev/` directory is the Terraform root module for the
development environment. It composes all modules described above.

### Module Wiring

```
module "vpc"  --> provides subnet IDs to: rds, eks
module "sg"   --> provides security group IDs to: rds
module "iam"  --> provides role ARNs to: eks
module "rds"  --> standalone (receives from vpc, sg)
module "ecr"  --> standalone
module "s3"   --> standalone
module "eks"  --> receives from vpc, iam
```

### Variable Defaults Summary (dev)

| Category   | Key Setting                  | Value                  |
|------------|------------------------------|------------------------|
| Networking | VPC CIDR                     | `10.0.0.0/16`         |
| Networking | Public Subnets               | `10.0.1.0/24`, `10.0.3.0/24` |
| Networking | Private Subnets              | `10.0.2.0/24`, `10.0.4.0/24` |
| Database   | Engine                       | MySQL 8.4.7            |
| Database   | Instance Class               | `db.t4g.micro`         |
| Database   | Storage                      | 20 GB (max 100 GB)     |
| Compute    | EKS Node Instance Type       | `t3.small`             |
| Compute    | Node Count (desired/min/max) | 5 / 5 / 6              |
| Storage    | S3 Bucket                    | `mogambo-platform-bucket` |
| CDN        | Price Class                  | `PriceClass_100`       |

---

## Module Dependency Graph

```
VPC
 |
 +---> SG (vpc_id)
 |      |
 |      +---> RDS (catalogue_db_sg_id)
 |
 +---> RDS (private_subnet_ids)
 |
 +---> EKS (private_subnet_ids)
 |
IAM ----> EKS (eks_cluster_role_arn, eks_node_group_role_arn)

ECR (standalone)

S3 + CloudFront (standalone)
```

---

## Security Considerations

### Network Isolation
- EKS nodes and RDS instances run in **private subnets** with no direct
  internet access. Outbound traffic is routed through a NAT gateway.
- The ALB is the only component exposed in public subnets.

### Encryption
- S3: Server-side encryption with AES-256.
- ECR: KMS encryption at rest.
- RDS: Default AWS encryption (configurable).
- Terraform state: Encrypted at rest in S3.

### Access Control
- S3 bucket blocks all public access. Objects are accessible only through
  CloudFront via Origin Access Control (OAC) with SigV4 signing.
- ECR image tags are immutable to prevent supply-chain tampering.
- RDS is not publicly accessible; ingress is restricted to the EKS node
  security group on port 3306 only.
- IAM roles follow least-privilege with AWS managed policies.

### State Management
- Remote state in S3 with DynamoDB-based locking prevents concurrent
  modifications and state corruption.
- State file is environment-isolated by key prefix (`dev/`, `staging/`, `prod/`).

### Sensitive Values
- `db_password` is marked `sensitive = true` in Terraform and will not
  appear in plan output or state diffs.
- For production, migrate database credentials to AWS Secrets Manager or
  SSM Parameter Store and reference them dynamically.

---

## Operational Procedures

### Initial Setup

```bash
# Navigate to the environment directory
cd infra/terraform/environments/dev

# Initialize Terraform (downloads providers, configures backend)
terraform init

# Review the execution plan
terraform plan

# Apply the infrastructure
terraform apply
```

### Updating Infrastructure

```bash
# After modifying any module or variable
terraform plan       # Review changes
terraform apply      # Apply changes
```

### Destroying Infrastructure

```bash
terraform destroy    # Removes all managed resources
```

### Viewing Outputs

```bash
terraform output                    # All outputs
terraform output eks_cluster_name   # Specific output
terraform output -json              # JSON format for automation
```

### Adding a New Environment

1. Create a new directory under `environments/` (e.g., `staging/`).
2. Copy `backend.tf`, `main.tf`, `outputs.tf`, `providers.tf`,
   `variables.tf`, and `versions.tf` from `dev/`.
3. Update `backend.tf` to use a unique state key (e.g., `staging/terraform.tfstate`).
4. Adjust variable defaults in `variables.tf` for the target environment.
5. Run `terraform init` and `terraform apply`.
