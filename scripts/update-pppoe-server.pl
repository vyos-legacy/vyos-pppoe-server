#!/usr/bin/perl

use strict;
use lib "/opt/vyatta/share/perl5";
use Vyatta::PPPoEServerConfig;

my $PPPOE_INIT        = '/etc/init.d/pppoe-server';
my $FILE_CHAP_SECRETS = '/etc/ppp/secrets/chap-pppoe-server';
my $FILE_PPPOE_OPTS   = '/etc/ppp/pppoe-server-options';
my $FILE_RADIUS_CONF  = '/etc/radiusclient/radiusclient-pppoe.conf';
my $FILE_RADIUS_KEYS  = '/etc/radiusclient/servers-pppoe';

my $config = new Vyatta::PPPoEServerConfig;
my $oconfig = new Vyatta::PPPoEServerConfig;
$config->setup();
$oconfig->setupOrig();

if (!($config->isDifferentFrom($oconfig))) {
    # config not changed. do nothing.
    exit 0;
}

if ($config->isEmpty()) {
    if (!$oconfig->isEmpty()) {
        system("kill -TERM `pgrep -f 'pppd.* pppoe-server-options '` "
                . '>&/dev/null');
        system("$PPPOE_INIT stop");
    }
    exit 0;
}

my ($chap_secrets, $pppoe_conf, $radius_conf, $radius_keys, 
    $cmdline, $err) = (undef, undef, undef, undef, undef, undef);

while (1) {
    ($chap_secrets, $err) = $config->get_chap_secrets();
    last if (defined($err));
    ($pppoe_conf, $err) = $config->get_ppp_opts();
    last if (defined($err));
    ($cmdline, $err) = $config->get_pppoe_cmdline();
    last if (defined($err));
    ($radius_conf, $err) = $config->get_radius_conf();
    last if (defined($err));
    ($radius_keys, $err) = $config->get_radius_keys();
    last;
}
if (defined($err)) {
    print STDERR "PPPOE-server configuration error: $err.\n";
    exit 1;
}

exit 1 if (!$config->removeCfg($FILE_CHAP_SECRETS));
exit 1 if (!$config->removeCfg($FILE_PPPOE_OPTS));
exit 1 if (!$config->removeCfg($FILE_RADIUS_CONF));
exit 1 if (!$config->removeCfg($FILE_RADIUS_KEYS));

exit 1 if (!$config->writeCfg($FILE_CHAP_SECRETS, $chap_secrets, 1, 0));
exit 1 if (!$config->writeCfg($FILE_PPPOE_OPTS, $pppoe_conf, 0, 0));
exit 1 if (!$config->writeCfg($FILE_RADIUS_CONF, $radius_conf, 0, 0));
exit 1 if (!$config->writeCfg($FILE_RADIUS_KEYS, $radius_keys, 0, 0));

system('cat /etc/ppp/secrets/chap-* > /etc/ppp/chap-secrets');
if ($? >> 8) {
    print STDERR 
        "PPPOE-server configuration error: Cannot write chap-secrets.\n";
    exit 1;
}

if ($config->needsRestart($oconfig)) {
    # restart pppoe-server
    # XXX need to kill all pptpd instances since it does not keep track of
    # existing sessions and will start assigning IPs already in use.
    system("kill -TERM `pgrep -f 'pppd.* pppoe-server-options '` "
           . '>&/dev/null');
    my $cmd = "DAEMON_OPTS=\"$cmdline\" $PPPOE_INIT restart";
    my $rc = system($cmd);
    exit $rc;
}
exit 0;

