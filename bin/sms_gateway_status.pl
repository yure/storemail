#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;
use Dancer::Plugin::Email;

logfile('gateway_status');

sub error_msg {
	my $gateway_id = shift;
	my $settings = config->{gateways}->{$gateway_id};
	my $status = shift;
	my $msg = $settings->{host}. " PROBLEM. Status: ".to_json $status;
	return $msg;
}

sub email_alert {
	my $msg = shift;
	printt $msg;
	printt "Sending";
	email {
            from    => 'Storemail <grega.pompe@informa.si>',
            to      => config->{admin_email},
            subject => 'Storemail gateway problem',
            body    => $msg,
        };
}

my @errors;
for my $gateway_id (keys config->{gateways}){	
	my $settings = config->{gateways}->{$gateway_id};
	try{
		
		my $gateway = StoreMail::SMS->new( $settings );		
		#print to_json $gateway->check_status;
		my $status = $gateway->check_status;
		my $ok_count = 0;
		for my $sim_status (@{$status->{CMD}}){
			$ok_count++ if index($sim_status, 'Power off' ) > -1; 
			$ok_count++ if index($sim_status, 'Power on, Provisioned, Up, Active,Standard' ) > -1; 
		}
		push @errors, [$gateway_id, $status] unless $ok_count == $settings->{active_ports};
		#email_alert($gateway_id, $status) unless $ok_count == $settings->{active_ports};
	}
	catch {
		push @errors, [$gateway_id, {status => 'Timeout'}];
		#email_alert($gateway_id, {status => 'Timeout'});
	};
}

my $msg = join ("\n\n", map {error_msg(@$_)} @errors);

email_alert($msg);

print ".";
