# AIOps Incident Copilot

Microservices on AWS with full DevOps automation and observability, plus an AI agent
that investigates alerts and proposes (human-approved) fixes.

## Phase 1: run locally

    make up        # build and start everything
    make smoke     # place a test order
    open http://localhost:8080

| Service | Port | Backed by |
|---|---|---|
| frontend | 8080 | calls order-service |
| order-service | 8001 | Postgres, calls inventory + payment |
| payment-service | 8002 | stateless |
| inventory-service | 8003 | Redis |

Every service exposes `/health`, `/metrics` (Prometheus) and `/faults` (fault injection).

    ./scripts/fault.sh payment latency 3000
    ./scripts/fault.sh payment errors 0.5
    ./scripts/fault.sh payment leak 100
    ./scripts/fault.sh payment reset

## Phase 2: AWS with Terraform, hosts with Ansible

Terraform builds: VPC (2 public + 2 private subnets, IGW, optional NAT), security groups,
IAM instance profile, ECR repositories, and three Ubuntu 24.04 hosts:
`bastion` (public), `ci` (private, Jenkins in phase 3), `k3s` (private, Kubernetes in phase 3).
State lives in S3 with DynamoDB locking.

Ansible configures them: SSH and kernel hardening, fail2ban, automatic security updates,
a systemd health-check timer, node_exporter, and Docker on the CI host.
Hosts are found through the dynamic AWS inventory (tag `Project=aiops`).

    ssh-keygen -t ed25519 -f ~/.ssh/aiops -N ""
    cp terraform/envs/dev/terraform.tfvars.example terraform/envs/dev/terraform.tfvars   # set admin_cidr
    make tf-bootstrap && make tf-init
    make tf-plan && make tf-apply
    make ansible-deps && make ansible-ping
    make ansible-site
    make tf-destroy        # when you are done for the day

## Layout

`services/` app code and Dockerfile, `terraform/` (bootstrap, modules, envs/dev), `ansible/` (inventory, roles, playbooks),
`k8s/`, `jenkins/`, `ai-agent/`, `docs/`, `scripts/`.
