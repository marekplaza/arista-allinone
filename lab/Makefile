# arista-allinone lab Makefile (in the container: `mk <target>`, run from your lab directory)
# Targets follow https://github.com/marekplaza/cvaas_avd_L2LS; paths can be overridden:
#   mk start TOPO=my.clab.yml      mk build AVD_DIR=ansible
CURRENT_DIR := $(shell pwd)
TOPO      ?= $(CURRENT_DIR)/clab/topology.clab.yml
AVD_DIR   ?= $(CURRENT_DIR)/avd_inventory
REF_LAB   ?= /opt/cvaas_avd_L2LS
SUDO      := $(if $(filter 0,$(shell id -u)),,sudo)
ARCH      := $(shell uname -m)
CEOS_VER  ?=
CEOS_REL  ?= M
CEOS_TAG  ?= latest
CEOS_ARCH ?= $(if $(filter aarch64 arm64,$(ARCH)),-a,)

.PHONY: help
help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: init
init: ## Copy the reference L2LS lab (clab/ + avd_inventory/) into the current directory
	@[ ! -e clab ] && [ ! -e avd_inventory ] || { echo "clab/ or avd_inventory/ already exists here"; exit 1; }
	cp -r $(REF_LAB)/clab $(REF_LAB)/avd_inventory $(REF_LAB)/Makefile $(REF_LAB)/get_ceos.sh .
	@echo "Reference lab copied. Check image: in clab/topology.clab.yml (mk ceos-list)."

.PHONY: start
start: ## Deploy the lab
	$(SUDO) containerlab deploy --debug --topo $(TOPO) --max-workers 10 --timeout 5m --reconfigure

.PHONY: stop
stop: ## Destroy the lab
	$(SUDO) containerlab destroy --debug --topo $(TOPO) --cleanup

.PHONY: inspect
inspect: ## Inspect the lab
	@$(SUDO) containerlab inspect --topo $(TOPO)
	@echo ""
	@echo "You can check the lab status, hostnames and management addresses above."
	@echo "To connect to a lab device use \`ssh arista@<hostname>\` and password \`arista\`."

.PHONY: graph
graph: ## Serve the lab topology graph on port 50080
	$(SUDO) containerlab graph --topo $(TOPO)

.PHONY: build
build: ## Generate AVD configs
	cd $(AVD_DIR); ansible-playbook playbooks/avd_build.yml

.PHONY: deploy
deploy: ## Deploy AVD configs using eAPI
	cd $(AVD_DIR); ansible-playbook playbooks/avd_deploy.yml

.PHONY: deploy_cvp
deploy_cvp: ## Deploy AVD configs using CloudVision
	cd $(AVD_DIR) && \
	CVURL=$${CVURL:-www.cv-prod-euwest-2.arista.io} \
	CV_API_TOKEN=$${CV_API_TOKEN:-$$(cat $(CURRENT_DIR)/clab/cv-api-token)} \
	ansible-playbook playbooks/avd_deploy_cvp.yml

.PHONY: decommission_cvp
decommission_cvp: ## Decommission all lab devices from CVaaS inventory
	cd $(AVD_DIR) && \
	CV_API_TOKEN=$${CV_API_TOKEN:-$$(cat $(CURRENT_DIR)/clab/cv-api-token)} \
	ansible-playbook playbooks/cvp_decommission.yml

.PHONY: diff
diff: ## Show the diff between running config and designed config
	cd $(AVD_DIR); ansible-playbook --diff --check playbooks/avd_deploy.yml

.PHONY: test
test: ## validate the network state
	cd $(AVD_DIR); ansible-playbook playbooks/avd_validate.yml

.PHONY: anta
anta: ## Run ANTA NRFU directly (ANTA_INV=anta_inventory.yml ANTA_CAT=anta_catalog.yml)
	anta nrfu --inventory $${ANTA_INV:-anta_inventory.yml} --catalog $${ANTA_CAT:-anta_catalog.yml} \
	  --username $${LABUSERNAME:-arista} --password $${LABPASSPHRASE:-arista} table

.PHONY: ceos
ceos: ## Download + import latest cEOS-lab (ARISTA_TOKEN; CEOS_VER=4.35.1F, CEOS_REL=F)
	/opt/allinone/get_ceos.sh $(CEOS_ARCH) $(if $(CEOS_VER),-v $(CEOS_VER),-r $(CEOS_REL)) -t $(CEOS_TAG)

.PHONY: ceos-list
ceos-list: ## List local cEOS images
	@docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' | grep -iE 'ceos|REPOSITORY'

.PHONY: versions
versions: ## Show tool versions
	@containerlab version | grep -E 'version|commit' ; \
	for p in pyavd ansible-core ansible anta eos-downloader; do printf '%-16s %s\n' $$p "$$(pip show $$p 2>/dev/null | awk '/^Version:/{print $$2}')"; done ; \
	ansible-galaxy collection list -p $$ANSIBLE_COLLECTIONS_PATH 2>/dev/null | grep -E '^arista\.'
