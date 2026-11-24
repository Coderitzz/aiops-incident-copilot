SHELL := /bin/bash
TF_BOOT := terraform -chdir=terraform/bootstrap
TF_DEV  := terraform -chdir=terraform/envs/dev

.PHONY: up down logs ps smoke reset-faults \
        tf-bootstrap tf-init tf-fmt tf-plan tf-apply tf-destroy tf-output \
        ansible-deps ansible-ping ansible-check ansible-site ssh-bastion

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
	$(TF_DEV) init
	$(TF_DEV) plan

tf-apply:
	$(TF_DEV) apply

tf-destroy:              ## tear down everything to stop the AWS bill
	$(TF_DEV) destroy

tf-output:
	$(TF_DEV) output

# ---------- Phase 2: Ansible ----------
ansible-deps:
	pip install ansible boto3 botocore
	cd ansible && ansible-galaxy collection install -r requirements.yml

ansible-ping:
	export BASTION_IP=$$($(TF_DEV) output -raw bastion_public_ip) && cd ansible && ansible all -m ping

ansible-check:           ## dry run
	export BASTION_IP=$$($(TF_DEV) output -raw bastion_public_ip) && cd ansible && ansible-playbook playbooks/site.yml --check --diff

ansible-site:
	export BASTION_IP=$$($(TF_DEV) output -raw bastion_public_ip) && cd ansible && ansible-playbook playbooks/site.yml

ssh-bastion:
	ssh -i ~/.ssh/aiops ubuntu@$$($(TF_DEV) output -raw bastion_public_ip)
