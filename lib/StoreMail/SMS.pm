package StoreMail::SMS;
use Dancer ':syntax';

use Asterisk::AMI;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;
use Time::HiRes qw(sleep);
use URI::Escape;
use EV;
use Time::HiRes qw(sleep nanosleep);
use LWP::UserAgent;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use StoreMail::Gateway::NeogateTG;
use StoreMail::Gateway::Elastix;

# Expand settings file for easy access
config->{phone_numbers} = {};
for my $gateway_id (keys %{config->{gateways}}){

	my $domain = config->{gateways}->{$gateway_id}->{domain};
	config->{domains}->{$domain}->{gateways} ||= [];
	push @{config->{domains}->{$domain}->{gateways}}, $gateway_id;

	next unless config->{gateways}->{$gateway_id}->{ports};
	for my $port (keys %{config->{gateways}->{$gateway_id}->{ports}}){
		config->{phone_numbers}->{config->{gateways}->{$gateway_id}->{ports}->{$port}} = {port => $port, gateway_id => $gateway_id};
	}
}


sub send_queue {
	my $gateway = shift;
	my $port = shift;
	my $where = {send_queue => 1};
	$where->{port} = $port if $port;
	my $unsent = schema->resultset('SMS')->search($where, {order_by => {'-desc' => 'id'}});		
	while (my $sms = $unsent->next){		
	 	send_sms($sms);	 		 
	}	
}


sub send_sms {
	my ($sms) = @_;	

	# Skip non send domains
	unless(domain_setting($sms->domain, 'name')){
			printt $sms->domain. " missing config";
			printt $sms->id. " Skipping [".$sms->outgoing_to."] ". substr $sms->plain_body(plain_newline => 1), 0, 30;
			
			$sms->send_queue(undef);				
			$sms->update;
			return 0
	}

	if(not defined $sms->send_status and (not defined $sms->send_failed or $sms->send_failed < 3)){
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
	
	printt $sms->id. "[$port:".$sms->outgoing_to."] ". substr $sms->plain_body(plain_newline => 1), 0, 30;

	# Gateway
	my $gateway_id = $number_config->{gateway_id};
	my $gateway_settings = config->{gateways}->{$gateway_id};
	$gateway_settings->{instance_name} = config->{instance_name};
	my $gateway_type = $gateway_settings->{type};
	my $gateway;

	$sms->port($port);
	$sms->gateway_id($gateway_id);			
	
	if($gateway_type eq 'neogate_tg'){
		$gateway = StoreMail::Gateway::NeogateTG->new( $gateway_settings );
	
	} elsif ($gateway_type eq 'elastix') {
		$gateway = StoreMail::Gateway::Elastix->new( $gateway_settings );
	
	} else {
		$sms->failed and print "Invalid gateway type" and return 0;
	}

	
	if($gateway){
		$gateway->send($port, $sms) or $sms->failed and return 0;
	}
	else {
		$sms->failed and return 0;
	}
	$sms->update;
 	return 1;
}


sub send_sms_api {
	my $sms = shift;
	
	my $api_settings = config->{sms_api};
	my $gateway_settings = config->{gateways}->{$sms->gateway_id};

	printt $sms->id. "[smsapi:".$sms->outgoing_to."] ". substr $sms->plain_body(plain_newline => 1), 0, 30;

	my $ua = LWP::UserAgent->new;
	my $post_data = {
		username => $api_settings->{username},
		password => md5_hex ($api_settings->{pass}),
		from => $gateway_settings->{sms_api_number} || $api_settings->{default_number},
		to => $sms->outgoing_to,
		message => $sms->plain_body(plain_newline => 1),
	};
	
	my $resp = $ua->post($api_settings->{url}, $post_data);
	if ($resp->is_success and (index($resp->content, 'OK') > -1)) {
		
		$sms->failover_send_status(1);
		$sms->send_timestamp(DateTime::Format::MySQL->format_datetime(DateTime->now));
		$sms->send_failed(undef);
		
	    my $message = $resp->decoded_content;
	    print " | $message\n";
	}
	else {
 		$sms->send_failed(1);				
		$sms->failover_send_status($resp->code);
			    
	    print " | Error sending ". $resp->code .': '. $resp->message;
	}
	
	$sms->send_queue(undef);				
	$sms->update;
}


sub save_sms {
	my ($gateway_id, $port, $from, $body, $datetime) = @_;	
	
	print " no gateway" and return undef unless $gateway_id;
	print " no port" and return undef unless $port;
	my $gateway_settings = config->{gateways}->{$gateway_id} or print " gateway $gateway_id not found " and return undef;
	my $to = $gateway_settings->{ports}->{$port} or print " port $port not found" and return undef;
	
	printt "$datetime $from - $to [$body]" ;
	
	try{
		my $exists = schema->resultset('SMS')->search({
			frm => $from,
			to => $to,
			body => $body,
			send_timestamp => $datetime,
			domain => config->{gateways}->{$gateway_id}->{domain},
		})->count;
			
		unless($exists){
			schema->resultset('SMS')->create({
				gateway_id => $gateway_id,
				port => $port,
				frm => $from,
				to => $to,
				body => $body,
				send_timestamp => $datetime,
				direction => 'i',
				domain => config->{gateways}->{$gateway_id}->{domain},
				created => DateTime::Format::MySQL->format_datetime(DateTime->now),
			});
		} 
		
	}
	catch {
		warn "Unable to save SMS $gateway_id, $port, $from, $to, $body, $datetime ".$_;
		return 0;
	};

	return 1;	
} 


sub sms_send_status {
	my ($instance_id, $status) = @_;
	
	# Check if from same instance
	my ($id, $instance) = split '_', $instance_id, 2;
	return undef unless config->{instance_name} and $instance;
	return undef if $instance ne config->{instance_name};
	
	my $sms = schema->resultset('SMS')->find($id) or return undef;
	if($status){
		$sms->send_status($status);
		$sms->send_timestamp(DateTime::Format::MySQL->format_datetime(DateTime->now));
		$sms->send_failed(undef);
	        $sms->update;
	}
	else {
		$sms->failed;
		return 0;
	}
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
my $listener_gateway_settings;
sub asterisk_listner {
	
	# Gateway
	$gateway_id = shift;;
	$listener_gateway_settings = config->{gateways}->{$gateway_id};
	
	
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
		my $from = extract_phone $event->{Sender};		
		
		# Decode body
		my $body = $event->{Content};
		$body =~ s/\+/ /smg;
		$body = uri_unescape $body;
		
		# Recieve timezone fix
		my $format = new DateTime::Format::Strptime(pattern => "%Y-%m-%d %H:%M:%S", time_zone => $listener_gateway_settings->{timezone});
		my $time = $format->parse_datetime($event->{Recvtime});
		$time->set_time_zone("UTC");
		my $new_date = $time->ymd() . ' ' .$time->hms();
		
		my $respnose = save_sms($gateway_id, $event->{GsmSpan}, $from, $body, $new_date);
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
