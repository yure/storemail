package StoreMail::Gateway::NeogateTG;

use StoreMail::Helper;
use Asterisk::AMI;
use Try::Tiny;
use DateTime::Format::MySQL;


sub new {
    my ($class, $settings) = @_;
    my $self = {        
        %$settings
    };
    astman_init($self) or return undef;
    bless $self, $class;
    return $self;
}


sub astman_init {
	my $self = shift;
	try{
		$self->{astman} = Asterisk::AMI->new(PeerAddr => $self->{host},
	                                PeerPort => $self->{port},
	                                Username => $self->{username},
	                                Secret => $self->{pass},
	                        );
	}
	catch {
		warn "Unable to connect to asterisk: $_";
		return undef;
	} ;
	warn "Unable to connect to asterisk" and return undef unless $self->{astman};
	return 1;
}

 
sub command {
	my $self = shift;
	my $command = shift;
	
	return $self->{astman}->action({ Action => 'smscommand',
                         command => $command,
                        });
}
 
=Send response OK

{
   "CMD" : [],
   "COMPLETED" : 1,
   "Response" : "Follows",
   "Privilege" : "SMSCommand",
   "GOOD" : 1,
   "ActionID" : "2"
}

Slot status
{
   "ActionID" : "2",
   "CMD" : [
      "D-channel: 2",
      "Status: Power on, Provisioned, Up, Active,Standard",
      "Type: CPE",
      "Manufacturer: SIMCOM_Ltd",
      "Model Name: SIMCOM_SIM800",
      "Model IMEI: 862951028263961",
      "Model CBAND:  DCS_MODE,ALL_BAND",
      "Revision: 1308B05SIM800M32_20140625_1100",
      "Network Name: VEGA",
      "Network Status: Registered (Home network)",
      "Signal Quality (0,31): 19",
      "SIM IMSI: 293700203101881",
      "SIM SMS Center Number: +38670007007",
      "Send SMS Center Number: Undefined",
      "Last event: SMS send OK",
      "State: READY",
      "Last send AT: \u001a\\r\\n"
   ],
   "Response" : "Follows",
   "COMPLETED" : 1,
   "GOOD" : 1,
   "Privilege" : "SMSCommand"
}


=cut
 
 
sub send {
	my $self = shift;
	my ($port, $sms) = @_;
	
	my $port_status;
	try{
		$port_status = $self->check_slot_status($port)->{CMD}->{Status};
	};
	return 0 unless $port_status;
	return 0 unless $port_status eq 'Power on, Provisioned, Up, Active,Standard';	

	my $to = $sms->outgoing_to;	
	my $msg = $sms->plain_body;	
	my $id = $sms->id;
	$id .= '_' . $self->{instance_name} if $self->{instance_name};	
	my $response = $self->command("gsm send sms $port $to \"$msg\" $id");
	my $sent = $response->{COMPLETED} and $response->{GOOD} ? 1 : 0;
	
	if($sent){
	 	$sms->send_queue(undef);
		$sms->send_timestamp(DateTime::Format::MySQL->format_datetime(DateTime->now));
		print " | PUSHED";
	 	return 1; 	
 	}
 	else{
 		$sms->send_failed(1);				
		print " | ERROR";
	 	return 0; 
 	}
}

 
sub check_status {
	my $self = shift;		
	return $self->command("gsm show spans");
}

 
sub check_sms {
	my $self = shift;		
	return $self->command("gsm show spans");
}

 
sub check_slot_status {
	my $self = shift;		
	my $slot = shift;
	my $status = $self->command("gsm show span $slot");
	if($status->{CMD}){
		my $cmds;
		for my $c (@{$status->{CMD}}){
			my ($k, $v) = split ': ', $c;
			$cmds->{$k} = $v;
		}
		$status->{CMD} = $cmds;
	}		
	return $status;
}


sub port_state{	
	my $self = shift;		
	my $port_status = $self->check_slot_status(shift);
	return 'NOT GOOD' unless $port_status->{GOOD};
	return 'NOT COMPLETED' unless $port_status->{COMPLETED};
	return 'BAD STATUS: '.$port_status->{CMD}->{Status} unless $port_status->{CMD}->{Status} eq 'Power on, Provisioned, Up, Active,Standard';
		
	return $port_status->{CMD}->{State}, $port_status->{CMD}->{'Last event'};
}

1;
