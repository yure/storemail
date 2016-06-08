#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;
use Dancer::Plugin::Email;
use StoreMail::Gateway::NeogateTG;

logfile('gateway_status');

sub error_msg {
	my $gateway_id = shift;
	my $settings = config->{gateways}->{$gateway_id};
	my $status = shift;
        my $msg = $gateway_id.' '.$settings->{host}.':'.$settings->{port}. " PROBLEM. Status: ".to_json $status;
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

exit(0) if ( (localtime)[2] == 0 and (localtime)[1] < 3 );

for my $gateway_id (keys config->{gateways}){
	next unless config->{gateways}->{$gateway_id}->{type} eq 'neogate_tg';	
	printt $gateway_id;
	try{
	        my $settings = config->{gateways}->{$gateway_id};
		my $gateway = StoreMail::Gateway::NeogateTG->new( $settings );		
		#print to_json $gateway->check_status;
		my $status = $gateway->check_status || {status => 'Empty response'};
		my $ok_count = 0;
		if(@{$status->{CMD}}){
			for my $sim_status (@{$status->{CMD}}){
				$ok_count++ if index($sim_status, 'Power off' ) > -1; 
				$ok_count++ if index($sim_status, 'Power on, Provisioned, Up, Active,Standard' ) > -1; 
			}
			$status->{port_count} = "$ok_count / ".$settings->{active_ports};
			push @errors, [$gateway_id, $status] unless $ok_count == $settings->{active_ports};
		}
	}
	catch {
		push @errors, [$gateway_id, {status => $_, }];
	};
}

my $msg = join ("\n\n", map {error_msg(@$_)} @errors);

email_alert($msg) if $msg;

print ".";
