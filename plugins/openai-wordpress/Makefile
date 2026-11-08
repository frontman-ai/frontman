.PHONY: check check-upstream test test-release package package-draft sync-release release-artifact

NODE ?= mise exec node -- node

check:
	$(NODE) validate.mts

check-upstream:
	$(NODE) validate.mts --strict-upstream

test: test-release
	$(NODE) --test test_validate.mts

test-release:
	bash ../../scripts/test-openai-wordpress-release.sh

package:
	$(NODE) validate.mts --package

package-draft:
	$(NODE) validate.mts --package-draft

sync-release:
	$(NODE) release.mts sync "$(VERSION)"

release-artifact:
	$(NODE) release.mts artifact "$(VERSION)"
