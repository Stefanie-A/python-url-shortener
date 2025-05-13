
TF_DIR=./infrastructure

init:
	cd $(TF_DIR) && terraform init

up:
	cd $(TF_DIR) && terraform apply -auto-approve

down:
	cd $(TF_DIR) && terraform destroy -auto-approve

plan:
	cd $(TF_DIR) && terraform plan

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

validate:
	cd $(TF_DIR) && terraform validate

output:
	cd $(TF_DIR) && terraform output
