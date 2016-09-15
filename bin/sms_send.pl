#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;

unless(@ARGV){
	print "sms_send.pl FROM TO MSG\nTO can be 0 (send to default)\n";
	exit;
}
my ($from, $to, $msg) = @ARGV;

$to ||= config->{admin_phone};
printt "Sending from $from to $to message '$msg'";
	
printt "Sent ". schema->resultset('SMS')->create({
	direction => 'o',
	domain => 'test.storemail.com',			
	frm => $from, 
	to => $to, 
	body => $msg, 
	send_queue => 1,
});
print "\n";