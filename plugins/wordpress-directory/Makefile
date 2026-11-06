.PHONY: check check-upstream test package

check:
	mise exec node -- node validate.mts

check-upstream:
	mise exec node -- node validate.mts --strict-upstream

test:
	mise exec node -- node --test test_validate.mts

package:
	mise exec node -- node validate.mts --package
