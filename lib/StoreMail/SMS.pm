package StoreMail::SMS;
use Dancer ':syntax';

use StoreMail::Helper;
use Net::Telnet ();
use Asterisk::AMI;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Time::HiRes qw(sleep);
use URI::Escape;
use EV;
use Time::HiRes qw(sleep nanosleep);
use LWP::UserAgent;
use Digest::MD5 qw(md5 md5_hex md5_base64);
my $astman;

# Expand settings file for easy access
config->{phone_numbers} = {};
for my $gateway_id (keys config->{gateways}){

	my $domain = config->{gateways}->{$gateway_id}->{domain};
	config->{domains}->{$domain}->{gateways} ||= [];
	push @{config->{domains}->{$domain}->{gateways}}, $gateway_id;

	next unless config->{gateways}->{$gateway_id}->{ports};
	for my $port (keys config->{gateways}->{$gateway_id}->{ports}){
		config->{phone_numbers}->{config->{gateways}->{$gateway_id}->{ports}->{$port}} = {port => $port, gateway_id => $gateway_id};
	}
}


sub new {
    my ($class, $settings) = @_;
    my $self = {
        domain => shift,
        %$settings
    };
    astman_init($self) or return undef;
    bless $self, $class;
    return $self;
}


sub astman_init {
	my $self = shift;
	$self->{astman} = Asterisk::AMI->new(PeerAddr => $self->{host},
                                PeerPort => $self->{port},
                                Username => $self->{username},
                                Secret => $self->{pass},
                        );
 
	debug "Unable to connect to asterisk" and return undef unless $self->{astman};
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
	my ($port, $to, $msg, $id) = @_;
	return 
	return $self->command("gsm send sms $port $to \"$msg\" $id");
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


sub send_queue {
	my $gateway = shift;
	my $port = shift;
	my $where = {send_queue => 1};
	$where->{port} = $port if $port;
	my $unsent = schema->resultset('SMS')->search($where, {order_by => {'-desc' => 'id'}});
	print '.';	
	while (my $sms = $unsent->next){		
	 	send_sms($sms);	 		 
	}	
}


sub send_sms {
	my ($sms) = @_;	
	
	if(not defined $sms->send_status){
		send_sms_gateway($sms);
	}
	elsif(not defined $sms->failover_send_status){
		send_sms_api($sms);
	}
 	
 	return 0;
} 


sub send_sms_gateway {
	my $sms = shift;
	
	my $number_config = config->{phone_numbers}->{$sms->frm};
	
	my $port = $number_config->{port} or debug "No port set for ".$sms->frm and return 0;
	
	# Gateway
	my $gateway_id = $number_config->{gateway_id};
	my $gateway_settings = config->{gateways}->{$gateway_id};
	my $gateway = StoreMail::SMS->new( $gateway_settings ) or debug "Can't connect to gateway" and return 0;

	printt "Sending to port $port: ".$sms->to." | ". $sms->plain_body;	
	
	my $response = $gateway->send($port, $sms->to, $sms->plain_body, $sms->id); 
 	
 	if($response->{COMPLETED} and $response->{GOOD}){
	 	$sms->send_queue(undef);
		$sms->port($port);		
		$sms->gateway_id($gateway_id);		
		$sms->update;
	 	return 1; 	
 	}
 	else{
 		$sms->send_queue(undef);				
 		$sms->send_failed(1);				
		$sms->update;
	 	return 0; 
 	}
}


sub send_sms_api {
	my $sms = shift;
	
	my $api_settings = config->{sms_api};

	my $ua = LWP::UserAgent->new;
	my $post_data = {
		username => $api_settings->{username},
		password => md5_hex ($api_settings->{pass}),
		from => 'Primerjam',
		to => $sms->frm,
		message => $sms->plain_body,
	};
	
	my $resp = $ua->post($api_settings->{url}, $post_data);
	if ($resp->is_success) {
		
		$sms->send_queue(undef);							
		$sms->failover_send_status(1);
		$sms->send_failed(undef);	
		$sms->update;
		
	    my $message = $resp->decoded_content;
	    print "Received reply: $message\n";
	}
	else {
		$sms->send_queue(undef);				
 		$sms->send_failed(1);				
		$sms->failover_send_status($resp->code);
		$sms->update;
			    
	    printt "Error sending [$sms] ". $resp->code .': '. $resp->message;
	}
	
}


sub save_sms {
	my ($gateway_id, $port, $from, $to, $body, $datetime) = @_;	
	
	try{
		schema->resultset('SMS')->create({
			gateway_id => $gateway_id,
			port => $port,
			frm => $from,
			to => $to,
			body => $body,
			send_timestamp => $datetime,
			direction => 'i',
			domain => config->{gateways}->{$gateway_id}->{domain},
		});
	}
	catch {
		warn "Unable to save SMS $gateway_id, $port, $from, $to, $body, $datetime ".$_;
		return 0;
	};

	return 1;	
} 


sub sms_send_status {
	my ($id, $status) = @_;
	my $sms = schema->resultset('SMS')->find($id) or return undef;
	$sms->send_status($status);
	$sms->send_timestamp(DateTime::Format::MySQL->format_datetime(DateTime->now));
	$sms->update;
	return 1;	
} 


sub wait_for {
	my ($gateway, $port, $state, $last_state) = @_;
	
	my $current_state = '';
	my $last_event;
 	while($state ne $current_state){
 		sleep(0.1);
 		($current_state, $last_event) = $gateway->port_state($port); 		
 	}
 	return $last_event;
}


my $gateway_id;
sub listner {
	
	# Gateway
	$gateway_id = shift;;
	my $listener_gateway_settings = config->{gateways}->{$gateway_id};
	
	
	#Here is a very simple example of how to use event handlers. Please note that the key for the event handler 
	#is matched against the event type that asterisk sends. For example if asterisk sends 'Event: Hangup' you use a 
	#key of 'Hangup' to match it. This works for any event type that asterisk sends. 
	
	my $listener_astman = Asterisk::AMI->new(PeerAddr => $listener_gateway_settings->{host},
	                                PeerPort => $listener_gateway_settings->{port},
	                                Username => $listener_gateway_settings->{username},
	                                Secret => $listener_gateway_settings->{pass}, 
	                                Events => 'on', Handlers => { 
										default => \&do_event, 										
										UpdateSMSSend => \&sms_update_event,
										ReceivedSMS => \&sms_recieved_event,
									},
	                        ) or die "Can't connect to gateway";
	 
	printt "Astman listener up for gateway $gateway_id";
	
	sub do_event { 
		my ($asterisk, $event) = @_; 
		printt 'Yeah! Event Type: ' . $event->{'Event'} ;
	} 
	
	sub sms_recieved_event { 
		my ($asterisk, $event) = @_; 				
		my $gateway_settings = config->{gateways}->{$gateway_id};

		my $to = $gateway_settings->{ports}->{$event->{GsmSpan}};
		my $from = extract_phone $event->{Sender};		
		
		# Decode body
		my $body = $event->{Content};
		$body =~ s/\+/ /smg;
		$body = uri_unescape $body;
		printt "$from - $to [$body]" ;
		
		my $respnose = save_sms($gateway_id, $event->{GsmSpan}, $from, $to, $body, $event->{Recvtime});
		print $respnose ? " saved":" not saved";
	} 
	
	sub sms_update_event { 
		my ($asterisk, $event) = @_; 
		printt "STATUS: ".$event->{ID}.': ' . $event->{Status} ;
		sms_send_status($event->{ID}, $event->{Status});
		print " updated";
	} 
	
	sub do_hangup { 
		my ($asterisk, $event) = @_; 
		printt 'Channel ' . $event->{'Channel'} . ' Hungup because ' . $event->{'Cause-txt'} ;
	} 
	
	EV::loop;
	
}
1;