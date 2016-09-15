#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;


my $numbers = config->{phone_numbers};

for my $number (keys %$numbers){
	printt $number;
	
	my $sms = schema->resultset('SMS')->create({
		direction => 'o',
		domain => 'test.storemail.com',			
		frm => $number, 
		to => config->{admin_phone}, 
		body => "Test from $number", 
		send_queue => 1,
    });
}
