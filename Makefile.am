cfgdir		    = $(datadir)/vyatta-cfg/templates
opdir		    = $(datadir)/vyatta-op/templates
share_perl5dir	    = $(datarootdir)/perl5/Vyatta
bin_sudo_usersdir   = $(bindir)/sudo-users
pppoe_serverconfdir = $(sysconfdir)/pppoe-server
initddir            = /etc/init.d
sys_perl5dir = /usr/share/perl5/Net/Radius
sys_sbindir = /usr/sbin

sbin_SCRIPTS  = scripts/update-pppoe-server.pl
sbin_SCRIPTS += scripts/show-pppoe-server.pl

bin_sudo_users_SCRIPTS = scripts/kick-pppoe.pl

share_perl5_DATA = lib/Vyatta/PPPoEServerConfig.pm

initd_SCRIPTS = etc/init.d/pppoe-server

pppoe_serverconf_SCRIPTS  = scripts/ppp-ip-up
pppoe_serverconf_SCRIPTS += scripts/ppp-ip-down
pppoe_serverconf_SCRIPTS += scripts/start-pppoe-radius-disconnect

sys_perl5_DATA = lib/Net-Radius-2.103/Dictionary.pm
sys_perl5_DATA += lib/Net-Radius-2.103/Packet.pm

sys_sbin_SCRIPTS = scripts/pppoe-radius-disconnect
cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
  cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates-cfg; $(cpiop) $(DESTDIR)$(cfgdir)
	mkdir -p $(DESTDIR)$(opdir)
	cd templates-op; $(cpiop) $(DESTDIR)$(opdir)
	mkdir -p $(DESTDIR)/etc/ppp/ip-pre-up.d 
	cp scripts/rename-pppoe $(DESTDIR)/etc/ppp/ip-pre-up.d/0006rename-pppoe-server
	chmod 755 $(DESTDIR)/etc/ppp/ip-pre-up.d/0006rename-pppoe-server
