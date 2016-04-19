#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;

use Time::HiRes qw(sleep nanosleep);

my $slot = pop @ARGV || 2; 

printt "Slot $slot";

my $gateway = StoreMail::SMS->new('dev.primerjam.si', 'Neogate TG API', ) or die "Can't connect to gateway";

my $last_event = '';
while(1){
	my $s = $gateway->check_slot_status($slot)->{CMD};
	my $event = "Last: ".$s->{'Last event'}." State: ".$s->{'State'};
	printt $event if $last_event ne $event;
	$last_event = $event;
	sleep(0.1);
}
