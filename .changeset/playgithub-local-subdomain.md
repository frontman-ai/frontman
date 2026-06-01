---
---

Add local PlayGithub subdomain routing for the Phoenix server at playgithub.frontman.local, including string-only parsing for repository, tree, and issue paths, plus explicit Daytona `?command=create|start|clone|install|dev` steps for sandbox launch/start, asynchronous repository clone with exit-code based failure labels, separate Daytona sandboxes and target-local dependency installs for tree-subdirectory targets, dependency install before asynchronous initial `@frontman-ai/astro` install, live install logs, dev-server launch with signed preview/proxy URLs, explicit failure labels, failure output, and `retry=true`, and stopped-sandbox resume before clone/install.
