.DEFAULT_GOAL := test
.PHONY: test pack consumer

ASTRO_VERSION ?= 6
PACKAGE_DIR := ../../libs/frontman-astro
ARTIFACT_DIR := $(CURDIR)/.artifacts
PACK_JSON := $(ARTIFACT_DIR)/pack.json

pack:
	@mkdir -p "$(ARTIFACT_DIR)"
	@npm pack --json --pack-destination "$(ARTIFACT_DIR)" "$(PACKAGE_DIR)" > "$(PACK_JSON)"
	@node assert-pack.mjs "$(PACK_JSON)"

consumer: pack
	@TARBALL=$$(node -e 'const p=require("$(PACK_JSON)")[0]; process.stdout.write(require("node:path").resolve("$(ARTIFACT_DIR)", p.filename))'); \
	node run-consumer.mjs "$(ASTRO_VERSION)" "$$TARBALL"

test: consumer
