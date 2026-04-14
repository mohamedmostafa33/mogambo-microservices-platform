# GitHub Workflows Documentation

## Purpose
This directory contains all GitHub Actions workflows used to validate, package, scan, and deploy the Mogambo platform services and infrastructure.

The workflows are designed around four principles:
- Run only when relevant files change.
- Keep build and test stages separate from image publishing.
- Publish container images only on push events after successful validation.
- Use OIDC-based AWS authentication for ECR and Terraform operations.

## Workflow Inventory

| Workflow File | Name | Trigger | Primary Responsibility |
|---|---|---|---|
| `carts-ci.yml` | Carts CI Pipeline | Push to `dev`, PR to `dev`/`main` | Build/test carts service, scan, build image, push to ECR, and update Helm image tag |
| `catalogue-ci.yml` | Catalogue CI Pipeline | Push to `dev`, PR to `dev`/`main` | Build/test catalogue service, scan, build image, push to ECR, and update Helm image tag |
| `frontend-ci.yml` | Front-end CI Pipeline | Push to `dev`, PR to `dev`/`main` | Build/test frontend service, scan, build image, push to ECR, and update Helm image tag |
| `infra.yml` | Infrastructure Deployment Pipeline | Manual (`workflow_dispatch`) | Terraform plan/apply/destroy/outputs for dev environment |

## Shared CI Design
Service CI workflows (`carts-ci.yml`, `catalogue-ci.yml`, `frontend-ci.yml`) follow the same high-level structure:

1. `detect-changes`
- Uses `dorny/paths-filter` to decide whether the service changed.
- Exposes a boolean output consumed by downstream jobs.

2. `build-and-test`
- Runs only when that service has changed.
- Installs language runtime and dependencies.
- Runs tests and optional static/security analysis.
- Runs Sonar analysis only when Sonar secrets are present.

3. `docker`
- Runs only on `push` events.
- Runs only when `detect-changes` is true and `build-and-test` succeeded.
- Builds image, tags with short commit SHA, scans with Trivy, and pushes to ECR.
- Exposes `commit_sha` as a job output for downstream jobs.

4. `update-helm-values`
- Runs only when the `docker` job succeeds.
- Updates service Helm values image `tag` with the just-pushed image SHA tag.
- Commits only when a real values change is detected (idempotent update).
- Pushes the Helm values update commit to `dev` with `[skip ci]` to avoid workflow loops.

## Required Secrets

### AWS / ECR
- `AWS_ROLE_TO_ASSUME`
- `AWS_ECR_REGISTRY_URL`

### SonarQube (optional but recommended)
- `SONAR_TOKEN`
- `SONAR_HOST_URL`

If Sonar secrets are missing, Sonar-specific steps are skipped while the rest of CI continues.

## Service Workflow Details

### carts-ci.yml
Language stack: Java/Maven

Build and test flow:
- Java setup with Temurin 18.
- Maven dependency cache (`~/.m2/repository`).
- `mvn dependency:go-offline`.
- `mvn clean verify`.
- JaCoCo report generation.

Quality and security:
- OWASP dependency check (`continue-on-error: true`).
- Sonar Java analysis with JaCoCo XML report path.

Image publishing:
- Docker build context: `src/carts`.
- Image tag format: `mogambo-carts:<short_sha>`.
- Pushes to `${AWS_ECR_REGISTRY_URL}/mogambo-carts:<short_sha>`.

### catalogue-ci.yml
Language stack: Go (legacy GOPATH mode)

Build and test flow:
- Go setup (`GO111MODULE=off`, GOPATH layout expected by service).
- Go dependency retrieval.
- `go test`, `go vet`, and binary build.
- Coverage generation.

Quality and security:
- OWASP dependency check (`continue-on-error: true`).
- Sonar analysis for Go project.

Image publishing:
- Docker build context: `src/catalogue`.
- Image tag format: `mogambo-catalogue:<short_sha>`.
- Pushes to `${AWS_ECR_REGISTRY_URL}/mogambo-catalogue:<short_sha>`.

### frontend-ci.yml
Language stack: Node.js

Build and test flow:
- Node setup (v20) with npm cache.
- `npm ci --legacy-peer-deps`.
- `npm test` and `npm run build`.

Quality and security:
- OWASP dependency check (`continue-on-error: true`).
- Sonar JavaScript analysis (when Sonar secrets are present).

Image publishing:
- Docker build context: `src/front-end`.
- Image tag format: `mogambo-frontend:<short_sha>`.
- Pushes to `${AWS_ECR_REGISTRY_URL}/mogambo-frontend:<short_sha>`.

## Infrastructure Workflow Details

### infra.yml
This workflow is manually executed and supports controlled Terraform operations in `infra/terraform/environments/dev`.

Input: `action`
- `plan`
- `apply`
- `destroy`
- `outputs`

Execution sequence:
- Checkout
- Terraform setup
- AWS credentials via OIDC
- `terraform init`
- `terraform validate`
- Action-specific Terraform command

Use this workflow carefully. `apply` and `destroy` are state-changing operations.

## Operational Notes

### Branch behavior
- Service workflows validate on PRs and pushes.
- Docker push stages run only on push events.
- Helm values auto-update commits are pushed to `dev` after successful image publish.

### Security behavior
- OIDC is used for AWS authentication (`id-token: write`).
- Trivy and OWASP steps are non-blocking by default (`continue-on-error: true`).
  - Adjust this if you want strict security gates.

### Image traceability
All published images are tagged with short commit SHA for deterministic rollback and auditability.

## Troubleshooting Guide

### Workflow did not run for a service
- Check `detect-changes` output in job logs.
- Ensure modified files are under the service path filter.

### Docker job did not run
- Confirm event is `push` (not PR).
- Confirm `build-and-test` passed.
- Confirm service change flag is `true`.

### Sonar steps skipped
- Verify `SONAR_TOKEN` and `SONAR_HOST_URL` repository secrets.

### ECR push failed
- Verify `AWS_ROLE_TO_ASSUME` and `AWS_ECR_REGISTRY_URL`.
- Verify IAM role trust policy allows GitHub OIDC.
- Verify role permissions for ECR login and push.

### Terraform workflow failed
- Confirm selected action is valid.
- Confirm backend/state access is configured for the target account.
- Validate role permissions for the Terraform action being executed.

## Change Management Recommendations
- Keep workflow logic service-specific and avoid cross-service coupling.
- Pin action versions where possible.
- Review security gates (`continue-on-error`) regularly.
- When changing ports or runtime behavior in a service Dockerfile, validate related service discovery assumptions in dependent services before merging.
