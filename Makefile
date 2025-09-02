.PHONY: version version-major version-minor version-patch build tag push help

# Get current version
VERSION := $(shell cat VERSION 2>/dev/null || echo "1.0.0")
IMAGE_NAME := docker-cron
REGISTRY := ghcr.io/karlwolffgang

help: ## Show this help message
	@echo "Available commands:"
	@echo "  Current version: $(VERSION)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

version: ## Show current version
	@echo "Current version: $(VERSION)"

version-major: ## Bump major version
	@./version.sh major
	@echo "New version: $$(cat VERSION)"

version-minor: ## Bump minor version
	@./version.sh minor
	@echo "New version: $$(cat VERSION)"

version-patch: ## Bump patch version
	@./version.sh patch
	@echo "New version: $$(cat VERSION)"

build: ## Build Docker image with current version
	@echo "Building $(IMAGE_NAME):$(VERSION)"
	docker build -t $(IMAGE_NAME):$(VERSION) -t $(IMAGE_NAME):latest --build-arg VERSION=$(VERSION) .

tag: ## Tag image for registry
	docker tag $(IMAGE_NAME):$(VERSION) $(REGISTRY)/$(IMAGE_NAME):$(VERSION)
	docker tag $(IMAGE_NAME):$(VERSION) $(REGISTRY)/$(IMAGE_NAME):latest

push: tag ## Push image to registry
	docker push $(REGISTRY)/$(IMAGE_NAME):$(VERSION)
	docker push $(REGISTRY)/$(IMAGE_NAME):latest

release: ## Create a new release (bump patch, build, tag, push)
	@$(MAKE) version-patch
	@$(MAKE) build
	@$(MAKE) push
	@echo "Released version $$(cat VERSION)"

clean: ## Remove local images
	docker rmi -f $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest $(REGISTRY)/$(IMAGE_NAME):$(VERSION) $(REGISTRY)/$(IMAGE_NAME):latest 2>/dev/null || true
