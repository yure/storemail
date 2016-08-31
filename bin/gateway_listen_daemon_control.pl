#!/usr/bin/env perl
# get_gmail.pl
use Dancer ':script';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Helper;
use StoreMail::SMS;
use Try::Tiny; 
use Getopt::Long;

logfile('sms_event_listner_control');
my $gateway_listen = 'bin/gateway_listen_daemon.pl';
my @gateways = keys %{config->{gateways}};

GetOptions(    
    "restart" => \&restart,
    "start"   => \&run,
    "stop"    => \&stop,
    ) or die $!;
    
#-------- DAEMON STUFF --------

exit(0);



sub stop {
   for my $gateway_id (@gateways){
                next unless config->{gateways}->{$gateway_id}->{type} eq 'neogate_tg';
		system($gateway_listen, $gateway_id, '--stop');
	}
}



sub run {
	for my $gateway_id (@gateways){
		next unless config->{gateways}->{$gateway_id}->{type} eq 'neogate_tg';
		printt $gateway_id;
		system($gateway_listen, $gateway_id, '--start');
	}
}


sub restart {
	
	for my $gateway_id (@gateways){
		next unless config->{gateways}->{$gateway_id}->{type} eq 'neogate_tg';
                printt $gateway_id;
		system($gateway_listen, $gateway_id, '--restart');
	}
}
