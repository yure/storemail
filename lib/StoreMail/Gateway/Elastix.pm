package StoreMail::Gateway::Elastix;

use StoreMail::Helper;
use Asterisk::AMI;
use Try::Tiny;
use LWP::Simple;
use JSON::XS 'decode_json';
use DateTime::Format::MySQL;


sub new {
    my ($class, $settings) = @_;
    my $self = {
        domain => shift,
        %$settings
    };
    init($self) or return undef;
    bless $self, $class;
    return $self;
}


sub init {
	my $self = shift;
	try{
		#try to connect to gateway
	}
	catch {
		warn "Unable to connect to gateway: $_";
		return undef;
	} ;	
	return 1;
}

 
sub send {
	my $self = shift;
	my ($port, $sms) = @_;
	my $to = $sms->to;	
	my $msg = $sms->plain_body;	
	my $id = $sms->id;	
	my $host = $self->{host};
	my $username = $self->{username};
	my $pass = $self->{pass};
	my $url = "http://$host/sendsms?username=$username&password=$pass&phonenumber=$to&message=$msg&port=$port";
	#print " $url ";
	# Set failed
	$sms->send_failed(1);

	my $content = get $url or return 0;
	# {"message":"gsm-2.1","report":[{"0":[{"port":"gsm-2.1","phonenumber":"0038640255245","time":"2016-05-24 12:00:13","result":"success"}]}]}
	#print $content;
	$return = 0;
	try{
		if((index($content, 'Failed') == -1) and (index($content, '"result":"success"') > -1)){
			$sms->send_status(1);
			$sms->send_timestamp(DateTime::Format::MySQL->format_datetime(DateTime->now));
		 	$sms->send_queue(undef);
		 	$sms->send_failed(undef);
		 	$return = 1; 	
			print " | OK";
	 	} else {
	 		print " | ERROR $content";
	 	}
	}
	catch {
		print " | $_";
	};

	sleep(2); # Maybe SMS are sent too fast and some fail
	return $return;
}

 
sub check_status {
	my $self = shift;		
	return undef;
}

 
sub check_sms {
	my $self = shift;		
	return undef;
}

 
sub check_slot_status {
	my $self = shift;		
	my $slot = shift;
	return undef;
}


sub port_state{	
	my $self = shift;		
	return undef;
}

1;
