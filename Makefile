.PHONY: help up down plan test lint diagram
help: ## list targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'
up: ## build EVERYTHING end to end and prove it works
	./scripts/up.sh
down: ## delete EVERYTHING this repo created (PURGE=1 also drops the state)
	./scripts/down.sh $(if $(PURGE),--purge,)
plan: ## terraform plan only
	./scripts/up.sh --plan
test: ## live test suite against the running landing zone
	./scripts/test.sh
lint: ## terraform fmt + validate, bash syntax
	terraform -chdir=terraform fmt -check -recursive && terraform -chdir=terraform validate
	bash -n scripts/*.sh
diagram: ## regenerate docs/img/architecture.{svg,png}
	python3 docs/diagrams/architecture.py && python3 docs/diagrams/render.py docs/img/architecture.svg docs/img/architecture.png
