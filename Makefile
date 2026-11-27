SHELL := /bin/bash
TF_BOOT := terraform -chdir=terraform/bootstrap
TF_DEV  := terraform -chdir=terraform/envs/dev

SSH_KEY  ?= ~/.ssh/aiops
SSH_OPTS  = -i $(SSH_KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
BASTION   = $$($(TF_DEV) output -raw bastion_public_ip)
CI_IP     = $$($(TF_DEV) output -raw ci_private_ip)
K3S_IP    = $$($(TF_DEV) output -raw k3s_private_ip)
SSH_VIA_BASTION = ssh $(SSH_OPTS) -o ProxyCommand="ssh $(SSH_OPTS) -q -W %h:%p ubuntu@$(BASTION)"

.PHONY: up down logs ps smoke reset-faults test \
        tf-bootstrap tf-init tf-fmt tf-plan tf-apply tf-destroy tf-output \
        ansible-deps ansible-ping ansible-check ansible-site ansible-platform \
        ssh-bastion ssh-ci ssh-k3s jenkins-password jenkins-tunnel app-tunnel kubectl \
        helm-lint helm-template

# ---------- Phase 1: local stack ----------
up:
	docker compose up -d --build

down:
	docker compose down -v

logs:
	docker compose logs -f --tail=50

ps:
	docker compose ps

smoke:
	bash ./scripts/smoke_test.sh

reset-faults:
	@for p in 8001 8002 8003 8080; do curl -s -X DELETE localhost:$$p/faults >/dev/null; done; echo "faults cleared"

test:                    ## lint + unit tests (same script Jenkins runs)
	bash scripts/ci_test.sh

# ---------- Phase 2: Terraform ----------
tf-bootstrap:            ## run once: S3 state bucket + DynamoDB lock table
	$(TF_BOOT) init
	$(TF_BOOT) apply

tf-init:
	$(TF_DEV) init \
	  -backend-config="bucket=$$($(TF_BOOT) output -raw state_bucket)" \
	  -backend-config="dynamodb_table=$$($(TF_BOOT) output -raw lock_table)" \
	  -backend-config="region=$$($(TF_BOOT) output -raw region)" \
	  -backend-config="key=dev/terraform.tfstate" \
	  -backend-config="encrypt=true"

tf-fmt:
	terraform -chdir=terraform fmt -recursive

tf-plan:
	$(TF_DEV) plan

tf-apply:
	$(TF_DEV) apply

tf-destroy:              ## tear down everything to stop the AWS bill
	$(TF_DEV) destroy

tf-output:
	$(TF_DEV) output

# ---------- Phase 2/3: Ansible ----------
ansible-deps:
	pip install ansible boto3 botocore
	cd ansible && ansible-galaxy collection install -r requirements.yml

ansible-ping:
	export BASTION_IP=$(BASTION) && cd ansible && ansible all -m ping

ansible-check:           ## dry run of the baseline
	export BASTION_IP=$(BASTION) && cd ansible && ansible-playbook playbooks/site.yml --check --diff

ansible-site:            ## baseline: hardening, node_exporter, Docker
	export BASTION_IP=$(BASTION) && cd ansible && ansible-playbook playbooks/site.yml

ansible-platform:        ## phase 3: k3s, CI tooling, Jenkins
	export BASTION_IP=$(BASTION) && cd ansible && ansible-playbook playbooks/platform.yml

# ---------- Access helpers ----------
ssh-bastion:
	ssh $(SSH_OPTS) ubuntu@$(BASTION)

ssh-ci:
	$(SSH_VIA_BASTION) ubuntu@$(CI_IP)

ssh-k3s:
	$(SSH_VIA_BASTION) ubuntu@$(K3S_IP)

jenkins-password:
	$(SSH_VIA_BASTION) ubuntu@$(CI_IP) sudo cat /var/lib/jenkins/secrets/initialAdminPassword

jenkins-tunnel:          ## then open http://localhost:8080
	$(SSH_VIA_BASTION) -N -L 8080:localhost:8080 ubuntu@$(CI_IP)

app-tunnel:              ## then open http://localhost:8081
	$(SSH_VIA_BASTION) -N -L 8081:localhost:80 ubuntu@$(K3S_IP)

kubectl:                 ## usage: make kubectl ARGS="get pods -A"
	$(SSH_VIA_BASTION) ubuntu@$(K3S_IP) "kubectl $(ARGS)"

# ---------- Helm ----------
helm-lint:
	helm lint k8s/charts/aiops --set image.registry=example.com/aiops

helm-template:
	helm template aiops k8s/charts/aiops --set image.registry=example.com/aiops
