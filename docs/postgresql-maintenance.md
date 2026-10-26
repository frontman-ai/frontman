# PostgreSQL restart maintenance

## Scope and limits

This is a proposed host policy. Operator approval and installation are required.
It is not live remediation.

The policy sets a PostgreSQL-only `needrestart` override to zero.
It defers automatic selection of umbrella and cluster services without hiding stale services.
Other service overrides, package updates, and deployment behavior remain unchanged.
Old library code remains in database processes until controlled maintenance.
Schedule maintenance promptly, especially after security updates.

Package maintainer scripts, explicit commands, host reboots, and other tools can still restart PostgreSQL.
This policy does not guarantee zero downtime or prevent all restarts.

Upstream `needrestart` applies `override_rc` in automatic mode and reports deferred services:
https://github.com/liske/needrestart/blob/master/needrestart
Ubuntu package revisions can differ. The fixture tests do not run Ubuntu's process scanner.

## Install on an existing host

Do not rerun `server-setup.sh` on an existing host. It performs destructive initial configuration.

1. Obtain operator approval for the policy and a maintenance owner.
2. Use a reviewed checkout on the approved host.
3. Inspect `/etc/needrestart/needrestart.conf` and its `conf.d/*.conf` files.
4. Make sure that the main configuration loads those files.
5. Inspect `/usr/sbin/needrestart` for `override_rc` handling in automatic mode.
6. Stop if that implementation does not defer zero-valued overrides.
7. Resolve overlapping PostgreSQL overrides before installation. First-match behavior can depend on the package version.
8. Save any existing `90-frontman-postgresql.conf` outside `conf.d`.
9. Run the standalone installer from the checkout:

   ```sh
   sudo bash infra/production/install-postgresql-maintenance-policy.sh
   ```

The installer copies one configuration file. It does not restart services or run package updates.
It requires Perl and standard shell utilities. Repeated installation leaves identical content unchanged.
New-host setup installs the policy before its first package operation.

## Verify without restarts

1. Compare the installed file with `infra/production/needrestart-postgresql.conf`.
2. Inspect later configuration files for replacement of `override_rc`.
3. Run the list-only scan:

   ```sh
   sudo needrestart -r l
   ```

4. If PostgreSQL uses stale libraries, make sure that it appears under deferred service restarts.
5. If PostgreSQL is not stale, record that this scan cannot demonstrate deferral.
6. Demonstrate automatic-mode deferral only on a disposable Ubuntu fixture with the same package revision.

Never use `needrestart -r a` as a production verification command.

## Controlled maintenance

1. Obtain approval for an outage window and a recovery owner.
2. Record the active application slot, cluster unit, database baseline, and application readiness baseline.
3. Drain incoming traffic and background jobs through the approved maintenance procedure.
4. Wait for in-flight work to finish.
5. Run the existing backup procedure:

   ```sh
   sudo -u deploy /opt/frontman/backup-pg.sh
   ```

6. Verify the new archive and its restore test in an isolated database.
7. If the backup or restore test fails, stop maintenance.
8. Apply approved package updates within the outage window.
9. Explicitly restart the intended cluster:

   ```sh
   sudo systemctl restart postgresql@17-main.service
   sudo systemctl is-active postgresql@17-main.service
   sudo -u postgres pg_isready
   sudo -u postgres psql -d frontman_server_prod -c 'SELECT 1;'
   ```

10. Verify the active application slot at `/health/ready` on its local port (blue: 4000, green: 4001).
11. Verify database connections and an approved application smoke workflow.
12. Run `sudo needrestart -r l` to inspect remaining stale services.
13. Restore background jobs and traffic only after database and application readiness pass.
14. Observe errors against the recorded baseline before closing the window.

If readiness fails, keep traffic drained. Inspect the database and application service status.
Use the approved recovery procedure. Restore a verified backup only after the recovery owner approves possible data loss.
An application rollback does not undo database package updates.

## Rollback the policy

1. Obtain operator approval.
2. Delete only `/etc/needrestart/conf.d/90-frontman-postgresql.conf`, or restore its saved predecessor.
3. Run `sudo needrestart -r l`.
4. Record that future automatic package operations can select PostgreSQL for restart again.

No service restart is required for policy rollback.
