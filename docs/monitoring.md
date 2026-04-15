# Monitoring Overview

This repository now includes GitOps manifests to deploy Prometheus and Grafana using kube-prometheus-stack, plus ServiceMonitor targets for application metrics.

## Added Components

- ArgoCD app `monitoring-crds` to install Prometheus Operator CRDs first
- ArgoCD app `monitoring-stack` to install kube-prometheus-stack in namespace `monitoring`
- ArgoCD app `monitoring-targets` to deploy application scrape targets from `deploy/k8s/monitoring`
- ServiceMonitor for `catalogue` metrics at `/metrics`

## Current Metrics Readiness

- `catalogue`: metrics endpoint available at `/metrics` (HTTP 200)
- `front-end`: `/metrics` currently returns HTTP 500 and needs app fix
- `carts`: no working Prometheus scrape endpoint detected (`/metrics` and `/prometheus` return 404)

## Recommended Next Improvements

1. Front-end: fix `/metrics` handler for current `prom-client` version.
2. Carts: expose a stable metrics endpoint via Spring Boot Actuator + Micrometer Prometheus.
3. Add ServiceMonitors for front-end and carts once endpoints are stable.
4. Add Grafana dashboards for latency/error rate per service and infrastructure panels (CPU, memory, pod restarts).
5. Add Alertmanager rules for 5xx spikes, pod crash loops, and high API latency.
