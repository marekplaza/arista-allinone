# Host-side helpers: build the image and open a shell in it.
# Lab targets live in lab/Makefile and are available in the container as `mk <target>`.
IMAGE    ?= arista-allinone
TAG      ?= latest
LAB_DIR  ?= $(CURDIR)/work
ENV_FILE ?= $(CURDIR)/.env

.PHONY: help
help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: image
image: ## Build the image (latest tool versions)
	docker build -t $(IMAGE):$(TAG) .

.PHONY: image-nocache
image-nocache: ## Rebuild from scratch to pick up new tool releases
	docker build --pull --no-cache -t $(IMAGE):$(TAG) .

.PHONY: shell
shell: ## Run the container with LAB_DIR mounted at the same path (LAB_DIR=~/lab)
	@mkdir -p $(LAB_DIR)
	docker run -it --rm --name allinone \
	  --privileged --network host --pid host \
	  -v /var/run/docker.sock:/var/run/docker.sock \
	  -v $(LAB_DIR):$(LAB_DIR) -w $(LAB_DIR) \
	  $(if $(wildcard $(ENV_FILE)),--env-file $(ENV_FILE)) \
	  $(IMAGE):$(TAG)

.PHONY: versions
versions: ## Show tool versions inside the image
	docker run --rm $(IMAGE):$(TAG) make -f /opt/allinone/Makefile versions
