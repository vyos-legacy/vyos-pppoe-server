#!/usr/bin/perl

use strict;

my $username = shift;
my $clearif  = shift;

my $SESSION_PATH = '/opt/vyatta/etc/pppoe-server/sessions';

if (!opendir(SDIR, "$SESSION_PATH")) {
    print STDERR "Cannot get session information\n";
    exit 1;
}
my @sessions = grep { /\@pppoes/ } readdir(SDIR);
if (!opendir(SDIR, "$SESSION_PATH")) {
    print STDERR "Cannot get session information\n";
    exit 1;
}

my @pids = ();
foreach my $ses (@sessions) {
    $ses =~ /^(.+)\@([^@]+)$/;
    my ($u, $intf) = ($1, $2);
    if (defined $clearif){
        if ($intf eq $username) {
            open(my $SFILE, '<', "$SESSION_PATH/$ses") or next;
            my $pid = <$SFILE>;
            close($SFILE);
            chomp($pid);
            next if (!($pid =~ /^\d+$/));
            push @pids, $pid;
        }
    }
    else {
        if ($u eq $username) {
            open(my $SFILE, '<', "$SESSION_PATH/$ses") or next;
            my $pid = <$SFILE>;
            close($SFILE);
            chomp($pid);
            next if (!($pid =~ /^\d+$/));
            push @pids, $pid;
        }
    }
}

foreach my $pid (@pids) {
    kill('TERM', $pid);
}

exit 0;

