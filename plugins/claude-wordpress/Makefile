ROOT := ../..

.PHONY: toolchain check test package
toolchain:
	bash $(ROOT)/scripts/install-claude-wordpress-validator.sh

check:
	bash $(ROOT)/scripts/check-claude-wordpress.sh

test:
	bash $(ROOT)/scripts/test-claude-wordpress-package.sh
	bash $(ROOT)/scripts/test-claude-wordpress-version.sh

package:
	bash $(ROOT)/scripts/package-claude-wordpress.sh
