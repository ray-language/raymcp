# raymcp — common tasks. `make` (or `make help`) lists them.

.DEFAULT_GOAL := help
.PHONY: help build test test-native fmt demo tools clean

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-12s %s\n", $$1, $$2}'

build: ## The native binary, ./raymcp
	rm -f raymcp
	ray build --native --release -o raymcp src/main.ray

test: ## Tests on the VM (they launch the server with `ray run`)
	ray test

test-native: ## The same tests as native binaries
	ray test --native

fmt: ## Format the sources
	ray fmt -w src/*.ray tests/*.ray

tools: build ## What the server offers, through a real MCP client
	./raymcp tools --root ..

demo: build ## A turn of the agent against the scripted model (no API key needed)
	./raymcp ask --root .. --fake examples/demo.json --stream "¿qué hay abierto sobre ptr?"

clean: ## Remove the binary
	rm -f raymcp
