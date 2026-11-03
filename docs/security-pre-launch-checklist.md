# Security Pre-Launch Checklist

This checklist must be completed **before making the repository public** to protect self-hosted runners from malicious fork PRs.

Related: [Issue #328](https://github.com/frontman-ai/frontman/issues/328)

## ⚠️ CRITICAL WARNING: GitHub's Official Guidance

According to [GitHub's security hardening documentation](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#hardening-for-self-hosted-runners):

> **Self-hosted runners should almost NEVER be used for public repositories**, because any user can open pull requests against the repository and compromise the environment.

**Key points:**
- Even with environment protection rules and required reviews, **workflows are NOT run in an isolated environment**
- Fork PR workflows **still execute code on your self-hosted runners** before any approval
- Attackers can gain access to the runner environment, network, and potentially pivot to production
- Environment protection only guards **deployment**, not the **CI workflow execution itself**

### Recommended Options (in order of security):

1. **🥇 Migrate CI to GitHub-hosted runners** (most secure)
   - CI workflows (`ci.yml`, `changelog-check.yml`) run on GitHub's infrastructure
   - Only deploy workflows run on self-hosted runners (triggered by `push: main` only)
   - Fork PRs cannot access your infrastructure

2. **🥈 Use ephemeral JIT runners** with automation
   - Runners self-destruct after each job
   - Requires infrastructure automation to ensure clean environment
   - Reduced but not eliminated risk

3. **🥉 Keep repository private**
   - Continue using self-hosted runners
   - Access controls limit who can create PRs
   - Cannot share code publicly or accept community contributions

**Decision Required**: Choose an approach before making the repo public.

---

## Critical (Must Complete Before Going Public)

### 1. Enable Fork PR Approval Requirement
**Status**: ⬜ Not Started  
**Responsibility**: Repository Admin  
**Instructions**:
1. Navigate to: `Settings → Actions → General → Fork pull request workflows`
2. Select: **"Require approval for all outside collaborators"**
3. Verify the setting is saved

**Why**: Prevents fork PRs from running on self-hosted runners until a maintainer explicitly approves.

---

### 2. Configure Production Environment Protection Rules
**Status**: ⬜ Not Started  
**Responsibility**: Repository Admin  
**Instructions**:
1. Navigate to: `Settings → Environments → production`
2. Enable **Required reviewers**:
   - Add: `@BlueHotDog`
3. Set **Deployment branches**: **Protected branches only**
4. (Optional) Set **Wait timer**: **5 minutes**
5. Click **Save protection rules**

**Why**: Since CI runners share the same network as production, this ensures:
- Even if malicious code is merged, deployment requires manual approval
- Attackers cannot deploy from fork branches
- You get a window to cancel suspicious deployments

---

### 3. Enable Branch Protection with Code Owner Reviews
**Status**: ⬜ Not Started (requires public repo or GitHub Pro)  
**Responsibility**: Repository Admin  
**Instructions**:
1. Navigate to: `Settings → Branches → Branch protection rules → main`
2. Enable: **Require a pull request before merging**
3. Enable: **Require review from Code Owners**
4. Enable: **Require status checks to pass before merging**
5. Select required status checks: (all CI jobs)
6. Enable: **Require branches to be up to date before merging**
7. Click **Save changes**

**Why**: Ensures workflow file changes in `.github/workflows/` require review from trusted maintainers (defined in `.github/CODEOWNERS`).

**Note**: This feature requires either GitHub Pro or a public repository. Enable immediately after making the repo public.

---

## Already Completed ✅

### ✅ Restrictive Default GITHUB_TOKEN Permissions
**Completed in**: [PR #330](https://github.com/frontman-ai/frontman/pull/330)  
**Status**: ✅ Complete

Top-level `permissions: contents: read` added to:
- `.github/workflows/ci.yml`
- `.github/workflows/changelog-check.yml`

Jobs that need additional permissions escalate per-job.

---

### ✅ CODEOWNERS File
**Completed in**: [PR #330](https://github.com/frontman-ai/frontman/pull/330)  
**Status**: ✅ Complete

`.github/CODEOWNERS` created protecting:
- `.github/workflows/` (all workflow files)
- `.github/CODEOWNERS` (the file itself)
- `infra/` (infrastructure code)

Maintainer required for approval: `@BlueHotDog`

---

### ✅ Pin Third-Party Actions to Commit SHAs
**Completed in**: [PR #329](https://github.com/frontman-ai/frontman/pull/329)  
**Status**: ✅ Complete

All 69 action references across 6 workflow files pinned to immutable commit SHAs:
- `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`
- `actions/setup-node@6044e13b5dc448c55e2357c09f80417699197238 # v6.2.0`
- `actions/cache@cdf6c1fa76f9f475f3d7449005a359c84ca0f306 # v5.0.3`
- `dorny/paths-filter@...`
- `jdx/mise-action@...`
- `cloudflare/wrangler-action@...`
- `5monkeys/cobertura-action@...` (previously highest risk: `@master`)

---

### ✅ Secrets Isolated to Deploy Workflows
**Status**: ✅ Complete (verified)

**CI workflows use zero production secrets**:
- `ci.yml` - No secrets
- `changelog-check.yml` - No secrets

**Deploy workflows use `environment: production`**:
- `deploy.yml` - Uses `PROD_SERVER`, `DEPLOY_SSH_KEY_B64`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`
- `deploy-marketing.yml` - Uses `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`

Even if an attacker compromises a CI job, they cannot access production credentials.

---

## Recommended (Strong Additional Hardening)

### Switch to Ephemeral Runners
**Status**: ⬜ Not Started  
**Responsibility**: Infrastructure Team  
**Priority**: Medium

Configure self-hosted runners with the `--ephemeral` flag:
```bash
./config.sh --url https://github.com/frontman-ai/frontman --token TOKEN --ephemeral
```

**Why**: Each runner picks up exactly one job then unregisters. Prevents state leakage between jobs (e.g., a malicious job leaving a backdoor for a subsequent deploy job).

---

## ⚠️ IMPORTANT: Limitations of Current Approach

**Even with all compensating controls in place**, the current setup has a fundamental security gap:

### What's Protected ✅
- Production secrets are isolated (not accessible to CI workflows)
- Deployments require manual approval
- Workflow files protected by CODEOWNERS

### What's NOT Protected ❌
According to GitHub's documentation:
- **CI workflows still execute on self-hosted runners** before any approval
- Fork PR approval only prevents *automatic* execution - maintainers may approve malicious code
- Attackers can:
  - Compromise the runner environment
  - Access the runner's network (including production if on same network)
  - Leave persistent backdoors on the runner
  - Exfiltrate data accessible to the runner
  - Pivot to production services if network-accessible

### Attack Scenarios That Current Controls DON'T Prevent

**Scenario 1: Compromised Runner Environment**
1. Attacker opens PR with malicious code
2. Maintainer approves (fork PR approval requirement)
3. CI workflow executes on self-hosted runner
4. Malicious code: compromises runner, installs backdoor
5. Result: Attacker has persistent access to runner environment

**Scenario 2: Network Pivot**
1. Attacker opens PR with malicious code
2. Maintainer approves
3. CI workflow scans network from runner
4. Discovers production server on same network
5. Attempts to exploit production services directly (SSH, database, etc.)

**Scenario 3: Resource Abuse**
1. Attacker opens many PRs with cryptocurrency mining code
2. Maintainers may approve thinking it's legitimate
3. Runners execute mining operations
4. Infrastructure costs spike, performance degrades

### Defense-in-Depth Summary (Updated)

With all critical items completed, an attacker attempting to **deploy** to production would need to:

1. ❌ **Create a malicious PR** → Blocked by fork PR approval requirement
2. ❌ **Get code owner approval** → Blocked by CODEOWNERS protection
3. ❌ **Merge to main** → Blocked by branch protection rules
4. ❌ **Access production secrets** → Blocked by environment isolation
5. ❌ **Get deployment approval** → Blocked by required reviewers
6. ❌ **Deploy from a fork branch** → Blocked by deployment branch restriction

**However**, an attacker can still:
- ✅ **Execute code on CI runners** (if PR is approved by maintainer)
- ✅ **Compromise runner environment** (persistent access)
- ✅ **Pivot to production** (if on same network)

---

## Pre-Launch Verification

Before making the repo public, verify all critical items:

```bash
# 1. Check CODEOWNERS exists
[ -f .github/CODEOWNERS ] && echo "✅ CODEOWNERS exists" || echo "❌ CODEOWNERS missing"

# 2. Check ci.yml has restricted permissions
grep -q "^permissions:" .github/workflows/ci.yml && echo "✅ ci.yml has permissions block" || echo "❌ Missing permissions"

# 3. Check actions are pinned (no @v or @master references except in comments)
if ! grep -E 'uses:.*@(v[0-9]|master|main)' .github/workflows/*.yml | grep -v '#'; then
  echo "✅ All actions pinned to SHAs"
else
  echo "❌ Some actions not pinned"
fi

# 4. Check deploy workflows use environment protection
grep -q "environment: production" .github/workflows/deploy*.yml && echo "✅ Deploy workflows use environment" || echo "❌ Missing environment"
```

Then manually verify via GitHub UI:
- [ ] Fork PR approval is enabled
- [ ] Production environment has required reviewers
- [ ] Production environment has deployment branch restriction

---

## Recommended Next Steps

### Option 1: Migrate CI to GitHub-Hosted Runners (Recommended)

**Pros:**
- ✅ Eliminates risk of fork PRs compromising your infrastructure
- ✅ No runner maintenance overhead for CI
- ✅ Clean, ephemeral environment for every job
- ✅ Can still use self-hosted runners for deployment

**Cons:**
- Costs money (GitHub Actions minutes)
- May need to adjust workflows for GitHub-hosted runner environment

**Implementation:**
1. Update `ci.yml` and `changelog-check.yml`:
   ```yaml
   runs-on: ubuntu-latest  # instead of self-hosted
   ```
2. Keep `deploy.yml` and `deploy-marketing.yml` using `runs-on: self-hosted`
3. Test workflows on a branch before merging
4. Deploy workflows still run on your infrastructure (only triggered by push to main)

**Estimated cost:** ~$0-50/month depending on usage (free tier available)

---

### Option 2: Implement Ephemeral JIT Runners

**Pros:**
- ✅ No GitHub Actions minutes cost
- ✅ Runners self-destruct after each job
- ✅ Reduces (but doesn't eliminate) risk

**Cons:**
- ❌ Requires significant infrastructure automation
- ❌ Complex to set up and maintain
- ❌ Still allows code execution on your infrastructure
- ❌ Cannot guarantee clean environment if reusing hardware

**Implementation:**
- Use GitHub's REST API to create JIT runner configurations
- Automate runner provisioning (VM/container creation)
- Ensure runners use truly ephemeral infrastructure (not reused)
- See: [GitHub REST API for JIT runners](https://docs.github.com/en/rest/actions/self-hosted-runners#create-configuration-for-a-just-in-time-runner-for-an-organization)

---

### Option 3: Keep Repository Private

**Pros:**
- ✅ No changes required to current setup
- ✅ Access controls prevent untrusted PRs

**Cons:**
- ❌ Cannot accept community contributions
- ❌ Cannot share code publicly
- ❌ Limits potential user base and collaboration

---

## Post-Launch Tasks

After making the repo public (if you choose to):

1. **Enable branch protection with code owner reviews** (requires public repo)
2. **Monitor first few fork PRs closely** to verify approval workflow works
3. **Set up alerting** for deployment approvals (GitHub webhook → Slack/email)
4. **Implement chosen runner strategy** (GitHub-hosted for CI or JIT runners)
5. **Monitor runner logs** for suspicious activity
6. **Review and approve ALL fork PRs carefully** before allowing CI execution

---

## References

- [GitHub: Security hardening for self-hosted runners](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#hardening-for-self-hosted-runners)
- [GitHub: Self-hosted runners should never be used for public repositories](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#hardening-for-self-hosted-runners)
- [GitHub: Approving workflow runs from public forks](https://docs.github.com/en/actions/managing-workflow-runs/approving-workflow-runs-from-public-forks)
- [GitHub: Using environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub: JIT runners REST API](https://docs.github.com/en/rest/actions/self-hosted-runners#create-configuration-for-a-just-in-time-runner-for-an-organization)
