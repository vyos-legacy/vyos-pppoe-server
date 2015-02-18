package Vyatta::PPPoEServerConfig;

use strict;
use lib "/opt/vyatta/share/perl5";
use Vyatta::Config;
use Vyatta::Misc;
use NetAddr::IP;

my $cfg_delim_begin = '### Vyatta PPPOE Begin ###';
my $cfg_delim_end = '### Vyatta PPPOE End ###';

my %fields = (
    _client_ip_start  => undef,
    _client_ip_stop   => undef,
    _auth_mode        => undef,
    _mtu              => undef,
    _ac               => undef,
    _service          => undef,
    _radius_interim   => undef,
    _local_ip         => '10.255.253.0',
    _auth_local       => [],
    _auth_radius      => [],
    _auth_radius_keys => [],
    _dns              => [],
    _wins             => [],
    _intfs            => [],
    _is_empty         => 1,
);

sub new {
    my $that = shift;
    my $class = ref ($that) || $that;
    my $self = {
        %fields,
    };
    
    bless $self, $class;
    return $self;
}

sub setup_base {
    my ($self, $listNodes_func, $val_func, $vals_func, $exists_func) = @_;

    my $config = new Vyatta::Config;
    $config->setLevel('service pppoe-server');
    my @nodes = $config->$listNodes_func();
    if (scalar(@nodes) <= 0) {
        $self->{_is_empty} = 1;
        return 0;
    } else {
        $self->{_is_empty} = 0;
    }

    $self->{_client_ip_start} = $config->$val_func('client-ip-pool start');
    $self->{_client_ip_stop} = $config->$val_func('client-ip-pool stop');
    $self->{_auth_mode} = $config->$val_func('authentication mode');
    $self->{_mtu} = $config->$val_func('mtu');
    $self->{_ac} = $config->$val_func('access-concentrator');
    $self->{_service} = $config->$val_func('service-name');
    $self->{_radius_interim} 
        = $config->$val_func('radius default-interim-interval');
    my $local_ip = $config->$val_func('local-ip');
    $self->{_local_ip} = $local_ip if defined $local_ip;
    
    my @users = $config->$listNodes_func('authentication local-users username');
    foreach my $user (@users) {
        my $plvl = "authentication local-users username $user password";
        my $pass = $config->$val_func("$plvl");
        my $dlvl = "authentication local-users username $user disable";
        my $disable = 'enable';
        $disable = 'disable' if $config->$exists_func("$dlvl");
        my $ilvl = "authentication local-users username $user static-ip";
        my $ip = $config->$val_func("$ilvl");
        $ip = 'none' if ! defined $ip;
        $self->{_auth_local} = [ @{$self->{_auth_local}}, $user, $pass, 
                                 $disable, $ip ];
    }
  
    my @rservers = $config->$listNodes_func('authentication radius-server');
    foreach my $rserver (@rservers) {
        my $klvl = "authentication radius-server $rserver key";
        my $key = $config->$val_func($klvl);
        $self->{_auth_radius} = [ @{$self->{_auth_radius}}, $rserver ];
        if (defined($key)) {
            $self->{_auth_radius_keys} = [ @{$self->{_auth_radius_keys}}, $key ];
        }
        # later we will check if the two lists have the same length
    }
    my @intfs = $config->$vals_func('interface');
    foreach my $intf (@intfs) {
        $self->{_intfs} = [ @{$self->{_intfs}}, $intf];
    }
    
    my $tmp = $config->$val_func('dns-servers server-1');
    if (defined($tmp)) {
        $self->{_dns} = [ @{$self->{_dns}}, $tmp ];
    }
    $tmp = $config->$val_func('dns-servers server-2');
    if (defined($tmp)) {
        $self->{_dns} = [ @{$self->{_dns}}, $tmp ];
    }
    
    $tmp = $config->$val_func('wins-servers server-1');
    if (defined($tmp)) {
        $self->{_wins} = [ @{$self->{_wins}}, $tmp ];
    }
    $tmp = $config->$val_func('wins-servers server-2');
    if (defined($tmp)) {
        $self->{_wins} = [ @{$self->{_wins}}, $tmp ];
    }
    
    return 0;
}

sub setup {
    my ($self) = @_;
    
    $self->setup_base('listNodes', 'returnValue', 'returnValues', 'exists');
    return 0;
}

sub setupOrig {
    my ($self) = @_;
    
    $self->setup_base('listOrigNodes', 'returnOrigValue', 'returnOrigValue', 
                      'existsOrig');
    return 0;
}

sub listsDiff {
    my @a = @{$_[0]};
    my @b = @{$_[1]};
    return 1 if scalar @a != scalar @b;
    
    while (my $a = shift @a) {
        my $b = shift @b;
        return 1 if ($a ne $b);
    }
    return 0;
}

sub isDifferentFrom {
    my ($this, $that) = @_;

    return 1 if ($this->{_is_empty} ne $that->{_is_empty});
    return 1 if ($this->{_client_ip_start} ne $that->{_client_ip_start});
    return 1 if ($this->{_client_ip_stop} ne $that->{_client_ip_stop});
    return 1 if ($this->{_auth_mode} ne $that->{_auth_mode});
    return 1 if ($this->{_mtu} ne $that->{_mtu});
    return 1 if ($this->{_ac} ne $that->{_ac});
    return 1 if ($this->{_service} ne $that->{_service});
    return 1 if ($this->{_radius_interim} ne $that->{_radius_interim});
    return 1 if ($this->{_local_ip} ne $that->{_local_ip});

    return 1 if (listsDiff($this->{_auth_local}, $that->{_auth_local}));
    return 1 if (listsDiff($this->{_auth_radius}, $that->{_auth_radius}));
    return 1 if (listsDiff($this->{_auth_radius_keys},
                           $that->{_auth_radius_keys}));
    return 1 if (listsDiff($this->{_dns}, $that->{_dns}));
    return 1 if (listsDiff($this->{_wins}, $that->{_wins}));
    return 1 if (listsDiff($this->{_intfs}, $that->{_intfs}));
    
    return 0;
}

sub needsRestart {
    my ($this, $that) = @_;

    return 1 if ($this->{_is_empty} ne $that->{_is_empty});
    return 1 if ($this->{_client_ip_start} ne $that->{_client_ip_start});
    return 1 if ($this->{_client_ip_stop} ne $that->{_client_ip_stop});
    return 1 if ($this->{_mtu} ne $that->{_mtu});
    return 1 if ($this->{_ac} ne $that->{_ac});
    return 1 if ($this->{_service} ne $that->{_service});
    return 1 if ($this->{_radius_interim} ne $that->{_radius_interim});
    return 1 if ($this->{_local_ip} ne $that->{_local_ip});
    return 1 if (listsDiff($this->{_intfs}, $that->{_intfs}));
    return 1 if (listsDiff($this->{_dns}, $that->{_dns}));
    return 1 if (listsDiff($this->{_wins}, $that->{_wins}));

    return 0;
}

sub isEmpty {
    my ($self) = @_;
    return $self->{_is_empty};
}

sub get_chap_secrets {
    my ($self) = @_;

    return (undef, "Authentication mode must be specified")
        if ! defined $self->{_auth_mode};

    my @users = @{$self->{_auth_local}};
    return (undef, "Local user authentication not defined")
        if $self->{_auth_mode} eq 'local' && scalar(@users) == 0;

    my $str = $cfg_delim_begin;
    if ($self->{_auth_mode} eq 'local') {
        while (scalar(@users) > 0) {
            my $user    = shift @users;
            my $pass    = shift @users;
            my $disable = shift @users;
            my $ip      = shift @users;
            if ($disable eq 'disable') {
                my $cmd = "/opt/vyatta/bin/sudo-users/kick-pppoe.pl" .
                    " \"$user\" 2> /dev/null";
                system ("$cmd");
            } else {
                my $service = 'pppoe-server';
                if ($ip eq 'none') {
                    $str .= ("\n$user\t" . $service . "\t\"$pass\"\t" . '*');
                }
                else {
                    $str .= ("\n$user\t" . $service . "\t\"$pass\"\t" . "$ip");
                }
            }
        }
    }
    $str .= "\n$cfg_delim_end\n";
    return ($str, undef);
}

sub get_ppp_opts {
    my ($self) = @_;

    my @dns = @{$self->{_dns}};
    my @wins = @{$self->{_wins}};
    my $sstr = '';
    foreach my $d (@dns) {
        $sstr .= "ms-dns $d\n";
    }
    foreach my $w (@wins) {
        $sstr .= "ms-wins $w\n";
    }
    my $rstr = '';
    if ($self->{_auth_mode} eq 'radius') {
        $rstr  = "plugin radius.so\n";
        $rstr .= "radius-config-file ";
        $rstr .= " /etc/radiusclient-ng/radiusclient-pppoe.conf\n";
        if (defined($self->{_radius_interim})) {
            $rstr .= "default-interim $self->{_radius_interim}\n";
        }
        $rstr .= "plugin radattr.so\n";
    }
    my $str;
    $str  = "$cfg_delim_begin\n";
    $str .= "name pppoe-server\n";
    $str .= "linkname pppoes\n";
    $str .= "plugin rp-pppoe.so\n";
#    $str .= "refuse-pap\n";
    $str .= "auth\n";
#    $str .= "refuse-chap\n";
#    $str .= "refuse-mschap\n";
    $str .= "require-chap\n";
#    $str .= "require-mschap-v2\n";
    $str .= ${sstr};
    $str .= "debug \n";
#    $str .= "lcp-echo-adaptive\n";
    $str .= "lcp-echo-interval 5\n";
    $str .= "lcp-echo-failure 6\n";
    $str .= "lcp-max-configure 10\n";
#    $str .= "nopassive\n";
    $str .= "proxyarp\n";
    $str .= "nobsdcomp\n";
    $str .= "novj\n";
    $str .= "novjccomp\n";
    $str .= "nologfd\n";

    if (defined ($self->{_mtu})){
        $str .= "mtu $self->{_mtu}\n";
        $str .= "mru $self->{_mtu}\n";
    }
    $str .= ${rstr};
    $str .= "$cfg_delim_end\n";
    return ($str, undef);
}

sub get_radius_conf {
    my ($self) = @_;

    my $mode = $self->{_auth_mode};
    return ("$cfg_delim_begin\n$cfg_delim_end\n", undef) 
        if $mode ne 'radius';

    my @auths = @{$self->{_auth_radius}};
    return (undef, "No Radius servers specified") if scalar @auths <= 0;
  
    my $authstr = '';
    foreach my $auth (@auths) {
        $authstr .= "authserver      $auth\n";
    }
    my $acctstr = $authstr;
    $acctstr =~ s/auth/acct/g;

    my $str;
    $str  = "$cfg_delim_begin\n";
    $str .= "auth_order      radius\n";
    $str .= "login_tries     4\n";
    $str .= "login_timeout   60\n";
    $str .= "nologin /etc/nologin\n";
    $str .= "issue   /etc/radiusclient-ng/issue\n";
    $str .= ${authstr} . ${acctstr};
    $str .= "servers         /etc/radiusclient-ng/servers-pppoe\n";
    $str .= "dictionary      /etc/radiusclient-ng/dictionary-ravpn\n";
    $str .= "login_radius    /usr/sbin/login.radius\n";
    $str .= "seqfile         /var/run/radius.seq\n";
    $str .= "mapfile         /etc/radiusclient-ng/port-id-map-ravpn\n";
    $str .= "default_realm\n";
    $str .= "radius_timeout  10\n";
    $str .= "radius_retries  3\n";
    $str .= "login_local     /bin/login\n";
    $str .= "$cfg_delim_end\n";

    return ($str, undef);
}

sub get_radius_keys {
    my ($self) = @_;

    my $mode = $self->{_auth_mode};
    return ("$cfg_delim_begin\n$cfg_delim_end\n", undef) 
        if $mode ne 'radius';
    
    my @auths = @{$self->{_auth_radius}};
    return (undef, "No Radius servers specified") 
        if scalar @auths <= 0;

    my @skeys = @{$self->{_auth_radius_keys}};
    return (undef, "Key must be specified for Radius server")
        if scalar @auths != scalar @skeys;
    
    my $str = $cfg_delim_begin;
    while ((scalar @auths) > 0) {
        my $auth = shift @auths;
        my $skey = shift @skeys;
        $str .= "\n$auth                $skey";
    }
    $str .= "\n$cfg_delim_end\n";
    return ($str, undef);
}
  
sub get_ip_str {
    my ($start, $stop, $local_ip) = @_;

    my $ip1 = new NetAddr::IP "$start/24";
    my $ip2 = new NetAddr::IP "$stop/24";
    if ($ip1->network() != $ip2->network()) {
        return (undef, 'Client IP pool not within a /24');
    }
    if ($ip1 >= $ip2) {
        return (undef, 'Stop IP must be higher than start IP');
    }

    my ($start_digit, $stop_digit, $num) = (undef, undef, undef);

    $start =~ m/\.(\d+)$/;
    $start_digit = $1;
    $stop =~ m/\.(\d+)$/;
    $stop_digit = $1;
    $num = ($stop_digit + 1) - $start_digit;
    
    return ("-L $local_ip -R $start -N $num -F", undef);
}

sub get_pppoe_cmdline {
    my ($self) = @_;

    my $str = '';
    my @intfs = @{$self->{_intfs}};
    return (undef, "Must define at least 1 interface")
        if scalar(@intfs) < 1;

    while (scalar(@intfs) > 0) {
        my $intf = shift @intfs;
        $str .= "-I $intf ";
    }

    my $cstart = $self->{_client_ip_start};
    return (undef, "Client IP pool start not defined") 
        if ! defined $cstart;

    my $cstop = $self->{_client_ip_stop};
    return (undef, "Client IP pool stop not defined") 
        if ! defined $cstop;

    my $local_ip = $self->{_local_ip};
    my ($ip_str, $err) = get_ip_str($cstart, $cstop, $local_ip);
    return (undef, "$err") 
        if ! defined $ip_str;

    $str .= $ip_str . " -k ";
    $str .= ' -s ';
    $str .= " -C " . $self->{_ac} if defined $self->{_ac};
    $str .= " -S " . $self->{_service} if defined $self->{_service};

    return ($str, undef);
}

sub removeCfg {
    my ($self, $file) = @_;

    system("sed -i '/$cfg_delim_begin/,/$cfg_delim_end/d' $file");
    if ($? >> 8) {
        print STDERR 
            "PPPoE configuration error: Cannot remove old config from $file.\n";
        
        return 0;
    }
    return 1;
}

sub writeCfg {
    my ($self, $file, $cfg, $append, $delim) = @_;

    my $op = ($append) ? '>>' : '>';
    my $WR = undef;
    if (!open($WR, $op, "$file")) {
        print STDERR 
            "PPPoE configuration error: Cannot write config to $file.\n";
        return 0;
    }
    if ($delim) {
        $cfg = "$cfg_delim_begin\n" . $cfg . "\n$cfg_delim_end\n";
    }
    print ${WR} "$cfg";
    close $WR;
    return 1;
}

sub print_str {
    my ($self) = @_;

    my $str = 'pppoe-server';
    $str .= "\n  intfs " . (join ",", @{$self->{_intfs}});
    $str .= "\n  cip_start " . $self->{_client_ip_start};
    $str .= "\n  cip_stop " . $self->{_client_ip_stop};
    $str .= "\n  auth_mode " . $self->{_auth_mode};
    $str .= "\n  auth_local " . (join ",", @{$self->{_auth_local}});
    $str .= "\n  auth_radius " . (join ",", @{$self->{_auth_radius}});
    $str .= "\n  auth_radius_s " . (join ",", @{$self->{_auth_radius_keys}});
    $str .= "\n  dns " . (join ",", @{$self->{_dns}});
    $str .= "\n  wins " . (join ",", @{$self->{_wins}});
    $str .= "\n  empty " . $self->{_is_empty};
    $str .= "\n";

  return $str;
}

1;
