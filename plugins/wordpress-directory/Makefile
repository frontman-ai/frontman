.PHONY: check check-upstream test package package-draft sync-release release-artifact

NODE ?= mise exec node -- node

check:
	$(NODE) validate.mts

check-upstream:
	$(NODE) validate.mts --strict-upstream

test:
	$(NODE) --test test_validate.mts

package:
	$(NODE) validate.mts --package

package-draft:
	$(NODE) validate.mts --package-draft

sync-release:
	$(NODE) release.mts sync "$(VERSION)"

release-artifact:
	$(NODE) release.mts artifact "$(VERSION)"
