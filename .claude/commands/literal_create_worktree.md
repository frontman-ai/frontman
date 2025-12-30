# Create Worktree for Feature Implementation

This skill automates worktree creation for frontman feature work.

## Steps

1. **Determine branch name from context**
   - Linear ticket: `eng-123-description`
   - Feature: `feature/description`
   - Fix: `fix/description`

2. **Create worktree**
   ```bash
   cd /home/bluehotdog/dev/frontman
   make worktree-create BRANCH=<branch-name>
   ```

3. **Navigate to worktree**
   ```bash
   cd .worktrees/<branch-name>
   ```

4. **Install dependencies (if needed)**
   ```bash
   # Usually no-op due to symlinked node_modules
   yarn install

   # For Elixir work:
   cd apps/frontman_server
   make install
   ```

5. **Verify setup**
   ```bash
   # Check Claude context
   ls -la .claude/

   # Verify node_modules symlink
   ls -la node_modules

   # Build to verify
   make build
   ```

6. **Inform user**
   - Worktree location: `.worktrees/<branch-name>`
   - Claude context is isolated (fresh history)
   - Ready for development

## Notes
- Each worktree has isolated Claude history
- Shared node_modules via symlink
- Push branch: `git push -u origin <branch-name>`
- Remove when done: `make worktree-remove NAME=<branch-name>`
