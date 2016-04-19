#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;
use Dancer::Plugin::Email;

logfile('gateway_status');

sub email_alert {
	my $gateway_id = shift;
	my $settings = config->{gateways}->{$gateway_id};
	my $status = shift;
	my $msg = $settings->{host}. " PROBLEM. Status: ".to_json $status;
	printt $msg;
	email {
            from    => 'Storemail <admin@storemail.com>',
            to      => config->{admin_email},
            subject => 'Storemail gateway problem',
            body    => $msg,
        };
}


for my $gateway_id (keys config->{gateways}){	
	my $settings = config->{gateways}->{$gateway_id};
	try{
		
		my $gateway = StoreMail::SMS->new( $settings );
		#print to_json $gateway->check_status;
		my $status = $gateway->check_status;
		my $ok_count = 0;
		for my $sim_status (@{$status->{CMD}}){
			$ok_count++ if index($sim_status, 'Power on, Provisioned, Up, Active,Standard' ) > -1; 
		}
		email_alert($gateway_id, $status) unless $ok_count == $settings->{active_ports};
	}
	catch {
		email_alert($gateway_id, {status => 'Timeout'});
	};
}

print ".";