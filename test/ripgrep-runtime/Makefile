.DEFAULT_GOAL := test
.PHONY: build pack test clean

PACKAGE ?= nextjs
PACKAGE_DIR := ../../libs/frontman-$(PACKAGE)
ARTIFACT_DIR := $(CURDIR)/.artifacts
PACK_JSON := $(ARTIFACT_DIR)/$(PACKAGE)-pack.json

build:
	@$(MAKE) -C "$(PACKAGE_DIR)" build

pack: build
	@mkdir -p "$(ARTIFACT_DIR)"
	@npm pack --json --pack-destination "$(ARTIFACT_DIR)" "$(PACKAGE_DIR)" > "$(PACK_JSON)"

test: pack
	@TARBALL=$$(node -e 'const p=require("$(PACK_JSON)")[0]; process.stdout.write(require("node:path").resolve("$(ARTIFACT_DIR)", p.filename))'); \
	node run-consumer.mjs "$(PACKAGE)" "$$TARBALL"

clean:
	@rm -rf "$(ARTIFACT_DIR)"
