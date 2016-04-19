#!/usr/bin/env perl
# get_gmail.pl
use Dancer ':script';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Helper;
use StoreMail::SMS;
use Try::Tiny; 
use Getopt::Long;

GetOptions(    
    "restart" => \&restart,
    "start"   => \&run,
    "stop"    => \&stop,
    ) or die $!;
    
#-------- DAEMON STUFF --------

exit(0);

sub stop {
   for my $gateway_id (keys config->{gateways}){
		system("bin/sms_listen_daemon.pl", $gateway_id, '--stop');
	}
}



sub run {
	for my $gateway_id (keys config->{gateways}){
		system("bin/sms_listen_daemon.pl", $gateway_id, '--start');
	}
}


sub restart
{  
    &stop;
    &run;
}
