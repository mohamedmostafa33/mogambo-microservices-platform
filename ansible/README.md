# Ansible Automation for SonarQube Provisioning

## Overview

This directory contains the Ansible implementation used to provision and configure a SonarQube server on Amazon Linux 2023 for the Mogambo Microservices Platform.

The automation is designed to be:

- idempotent
- environment-aware
- suitable for repeatable infrastructure operations
- aligned with enterprise configuration management practices

The current implementation provisions a single-host SonarQube deployment backed by a local PostgreSQL 15 instance and managed through `systemd`.

## Objectives

The Ansible automation covers the following responsibilities:

- validate that the target host is Amazon Linux 2023
- install the required operating system packages
- configure swap for resource-constrained instances
- apply SonarQube kernel and process limits
- install and initialize PostgreSQL 15
- create the SonarQube database and database user
- download and configure SonarQube
- install and manage the SonarQube `systemd` service
- expose port `9000` through `firewalld`
- verify service readiness using the SonarQube status API

## Directory Structure

```text
ansible/
├── ansible.cfg
├── README.md
├── requirements.yml
├── group_vars/
│   └── all.yml
├── inventory/
│   └── hosts.ini
├── playbooks/
│   └── setup_sonarqube.yml
└── roles/
    └── sonarqube/
        ├── defaults/
        │   └── main.yml
        ├── handlers/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        └── templates/
            ├── sonar.properties.j2
            └── sonarqube.service.j2
```

## Components

### `ansible.cfg`
Defines project-local Ansible behavior, including:

- inventory path
- default SSH user
- SSH pipelining
- fact caching
- role path
- collection path

### `inventory/hosts.ini`
Contains the target hosts for execution.

Example:

```ini
[sonarqube]
ec2 ansible_host=<EC2_PUBLIC_IP> ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/key.pem
```

### `group_vars/all.yml`
Contains environment-level overrides for SonarQube configuration such as:

- SonarQube version
- database credentials
- swap behavior
- JVM memory sizing
- service behavior

### `playbooks/setup_sonarqube.yml`
The entry point for provisioning the SonarQube host. This playbook applies the `sonarqube` role to hosts in the `sonarqube` inventory group.

### `roles/sonarqube`
Contains the implementation details.

#### `defaults/main.yml`
Defines the role defaults, including package names, filesystem layout, JVM settings, database parameters, kernel limits, and service settings.

#### `tasks/main.yml`
Implements the provisioning workflow.

#### `handlers/main.yml`
Defines operational handlers used to reload configuration or restart services when changes occur.

#### `templates/sonar.properties.j2`
Generates the SonarQube application configuration.

#### `templates/sonarqube.service.j2`
Generates the `systemd` service unit used to manage SonarQube.

## Execution Flow

The provisioning workflow executes in the following order:

1. validate the operating system
2. optionally update system packages
3. install Java, PostgreSQL, and required dependencies
4. configure swap when enabled
5. configure `sysctl` and process limits
6. create the service account and directory structure
7. initialize and start PostgreSQL
8. configure PostgreSQL local authentication
9. create the SonarQube database user and database
10. download and extract SonarQube
11. render SonarQube configuration files
12. install the `systemd` unit
13. start and enable SonarQube
14. wait for TCP readiness and API health confirmation

## Software and Runtime Profile

### Operating System
- Amazon Linux 2023

### Application Stack
- SonarQube `10.6.0.92116`
- PostgreSQL 15
- Java 17 Amazon Corretto Headless

### Service Endpoint
- SonarQube Web UI: `http://<host>:9000`

## Resource Profile

The role is tuned for conservative usage on relatively limited EC2 instances.

Current default JVM allocation values:

| Component | Xms | Xmx |
|---|---:|---:|
| Search | 768m | 768m |
| Web | 384m | 384m |
| Compute Engine | 384m | 384m |

Additional defaults:

- compute engine workers: `1`
- swap enabled: `true`
- swap size: `4 GB`

These defaults are intended to provide stable startup characteristics on modest EC2 instance sizes while maintaining acceptable SonarQube responsiveness.

## Key Variables

The most important variables available to operators are listed below.

| Variable | Purpose | Default |
|---|---|---|
| `sonarqube_version` | SonarQube version to install | `10.6.0.92116` |
| `sonarqube_port` | SonarQube listening port | `9000` |
| `sonarqube_db_name` | PostgreSQL database name | `sonarqube` |
| `sonarqube_db_user` | PostgreSQL database user | `sonar` |
| `sonarqube_db_password` | PostgreSQL database password | `ChangeMe_StrongPassword_123!` |
| `sonarqube_manage_swap` | Enables swap management | `true` |
| `sonarqube_swap_size_gb` | Swap file size in GB | `4` |
| `sonarqube_manage_firewalld` | Manages `firewalld` rules | `true` |
| `sonarqube_update_system` | Enables full package update before installation | `false` |
| `sonarqube_search_xms` | Search JVM initial heap | `768m` |
| `sonarqube_search_xmx` | Search JVM max heap | `768m` |
| `sonarqube_web_xms` | Web JVM initial heap | `384m` |
| `sonarqube_web_xmx` | Web JVM max heap | `384m` |
| `sonarqube_ce_xms` | Compute Engine JVM initial heap | `384m` |
| `sonarqube_ce_xmx` | Compute Engine JVM max heap | `384m` |
| `sonarqube_ce_worker_count` | Number of CE workers | `1` |

## Prerequisites

Before running the playbook, ensure the following prerequisites are met:

1. The target EC2 instance is reachable over SSH.
2. The inventory file contains the correct host IP or DNS value.
3. The SSH private key path in the inventory file is valid.
4. Ansible is installed on the control node.
5. Required collections are installed.

Install required collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Execution

Run the playbook from the `ansible` directory:

```bash
ansible-playbook playbooks/setup_sonarqube.yml
```

Optionally run in check mode when validating planned changes:

```bash
ansible-playbook playbooks/setup_sonarqube.yml --check
```

## Expected Outcome

A successful run produces the following end state:

- PostgreSQL is installed, enabled, and running
- the SonarQube database and user exist
- SonarQube is installed under `/opt/sonarqube`
- the active installation is referenced by `/opt/sonarqube/current`
- the `sonarqube` service is enabled and running
- port `9000/tcp` is opened in `firewalld`
- the SonarQube API returns `"status":"UP"`

## Post-Deployment Verification

Recommended validation commands on the target server:

```bash
sudo systemctl status postgresql --no-pager -l
sudo systemctl status sonarqube --no-pager -l
curl -s http://127.0.0.1:9000/api/system/status
```

The API should return a payload containing:

```text
"status":"UP"
```

## Idempotency

The automation is designed to be idempotent. A second run against a correctly provisioned host should complete with zero or near-zero changes.

This behavior confirms that:

- package installation is stable
- database creation tasks are safe to re-run
- configuration rendering does not drift unnecessarily
- service state is already aligned with the declared configuration

## Security Notes

The following controls are currently implemented:

- SonarQube runs as a dedicated non-login system user
- local PostgreSQL authentication is configured explicitly for loopback traffic
- required kernel and file descriptor settings are managed explicitly
- firewall exposure is limited to the SonarQube service port

The following improvements are recommended for production usage:

- replace plaintext credentials in `group_vars/all.yml` with Ansible Vault
- place SonarQube behind a reverse proxy such as NGINX
- terminate TLS with a trusted certificate
- restrict inbound access to approved source IP ranges or a private network path
- integrate backup and retention policy for PostgreSQL data

## Operational Notes

- The current deployment model is suitable for a dedicated SonarQube EC2 host.
- PostgreSQL is colocated on the same server for simplicity.
- For larger workloads, externalizing the database and adding a reverse proxy should be considered.
- Version upgrades can be controlled centrally through `sonarqube_version`.

## Troubleshooting

### SonarQube does not become healthy

Check:

```bash
sudo systemctl status sonarqube --no-pager -l
sudo journalctl -u sonarqube -n 200 --no-pager
sudo tail -n 200 /opt/sonarqube/logs/es.log
sudo tail -n 200 /opt/sonarqube/logs/web.log
sudo tail -n 200 /opt/sonarqube/logs/ce.log
```

### PostgreSQL issues

Check:

```bash
sudo systemctl status postgresql --no-pager -l
sudo journalctl -u postgresql -n 200 --no-pager
```

### Port accessibility issues

Check:

```bash
sudo firewall-cmd --list-ports
ss -lntp | grep 9000
```

## Change Management

When modifying this automation, follow these rules:

- keep all infrastructure behavior idempotent
- prefer native Ansible modules over shell commands when possible
- keep role defaults generic and environment overrides in `group_vars`
- update this document when behavior, prerequisites, or operational steps change

## Summary

This Ansible implementation provides a repeatable and maintainable method for provisioning SonarQube on Amazon Linux 2023 with PostgreSQL and `systemd` integration. It is suitable as a baseline for CI platform integration and can be extended to support reverse proxying, TLS, external databases, and additional hardening controls.
