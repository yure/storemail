#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;


my $from = DateTime::Format::MySQL->format_datetime(DateTime->now->subtract(minutes => 60));
my $to = DateTime::Format::MySQL->format_datetime(DateTime->now); 
printt "$from - $to";
my %created = (created => {-between => [$from, $to],});

my $normal_sent = schema->resultset('SMS')->search({
	%created,
	direction => 'o',
	send_status => 1,
})->count;

my $failover_sent = schema->resultset('SMS')->search({
	%created,
	direction => 'o',
	failover_send_status => 1,
})->count;

my $fail_sent = schema->resultset('SMS')->search({
	%created,
	direction => 'o',
	failover_send_status => {'>' => 1},
})->count;


print "Normal: $normal_sent
Failover: $failover_sent
Fail: $fail_sent";