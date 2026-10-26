#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT
export ROOT="${TMP}/root"
mkdir -p "${TMP}/bin" "${ROOT}/etc/needrestart/conf.d"
export CALLS="${TMP}/calls"
for command in systemctl service needrestart apt-get; do
  printf '#!/usr/bin/env bash\necho called >> "$CALLS"\nexit 1\n' > "${TMP}/bin/${command}"
  chmod +x "${TMP}/bin/${command}"
done
export PATH="${TMP}/bin:${PATH}"
printf '# existing configuration\n' > "${ROOT}/etc/needrestart/conf.d/10-existing.conf"
bash "${SCRIPT_DIR}/install-postgresql-maintenance-policy.sh"
DEST="${ROOT}/etc/needrestart/conf.d/90-frontman-postgresql.conf"
cmp "${SCRIPT_DIR}/needrestart-postgresql.conf" "${DEST}"
cp -p "${DEST}" "${TMP}/first"
bash "${SCRIPT_DIR}/install-postgresql-maintenance-policy.sh"
cmp "${TMP}/first" "${DEST}"
[[ ! "${DEST}" -nt "${TMP}/first" ]]
grep -qx '# existing configuration' "${ROOT}/etc/needrestart/conf.d/10-existing.conf"
[[ ! -e "${CALLS}" ]]
if ROOT=relative bash "${SCRIPT_DIR}/install-postgresql-maintenance-policy.sh"; then
  echo 'FAIL: accepted relative fixture root' >&2
  exit 1
fi

perl - "${DEST}" <<'PERL'
use strict;
use warnings;
our %nrconf = (
    restart => 'a',
    blacklist_rc => [],
    override_rc => { qr(^unrelated\.service$) => 0, qr(^caddy\.service$) => 1 },
);
my $original = $nrconf{override_rc};
my $loaded = do $ARGV[0];
die($@ || $! || "policy did not load") unless defined $loaded;
die "replaced overrides" unless $original == $nrconf{override_rc};
die "changed global mode" unless $nrconf{restart} eq 'a';
die "hid stale services" if @{$nrconf{blacklist_rc}};
die "unexpected overrides" unless keys %{$nrconf{override_rc}} == 3;
# Same first-matching-override selection as needrestart's automatic mode.
sub selected {
    my ($service) = @_;
    for my $re (sort keys %{$nrconf{override_rc}}) {
        return $nrconf{override_rc}->{$re} if $service =~ /$re/;
    }
    return 1;
}
for (qw(postgresql postgresql.service postgresql@17-main.service
        postgresql@18-other.service postgresql@17-main)) {
    die "not deferred: $_" if selected($_);
}
for (qw(caddy.service ssh.service frontman-blue.service postgresql-exporter.service
        not-postgresql.service postgresql.service.extra postgresql@17/main.service)) {
    die "unrelated service deferred: $_" unless selected($_);
}
die "lost unrelated override" if selected('unrelated.service');
print "PASS: narrow policy and preserved configuration\n";
PERL
echo 'PASS: offline installation, idempotence, and no service/package commands'
