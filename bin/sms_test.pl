#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;
use EV;
use LWP::UserAgent;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $api_settings = config->{sms_api};

my $ua = LWP::UserAgent->new;
my $post_data = {
	username => $api_settings->{username},
	password => md5_hex ($api_settings->{pass}),
	from => 'Primerjam',
	to => '0038640255245',
	message => 'Test from API',
};

my $resp = $ua->post($api_settings->{url}, $post_data);
if ($resp->is_success) {
    my $message = $resp->decoded_content;
    print $resp->code;
    
}
else {
    print "HTTP POST error code: ", $resp->code, "\n";
    print "HTTP POST error message: ", $resp->message, "\n";
}

=Gateway

# Gateway
my $sms_settings = domain_setting('dev.primerjam.si', 'sms');
my $gateway_settings = $sms_settings->{gateways}->{'TG400-1'};
my $gateway = StoreMail::SMS->new( $gateway_settings ) or die "Can't connect to gateway";


#Here is a very simple example of how to use event handlers. Please note that the key for the event handler 
#is matched against the event type that asterisk sends. For example if asterisk sends 'Event: Hangup' you use a 
#key of 'Hangup' to match it. This works for any event type that asterisk sends. 

my $astman = Asterisk::AMI->new(PeerAddr => $gateway_settings->{host},
                                PeerPort => $gateway_settings->{port},
                                Username => $gateway_settings->{username},
                                Secret => $gateway_settings->{pass}, 
                                Events => 'on', Handlers => { 
									default => \&do_event, 
									Hangup => \&do_hangup,
									UpdateSMSSend => \&sms_update_event,
									ReceivedSMS => \&sms_recieved_event,
								}
                        );
 
printt "Astman";

sub do_event { 
	my ($asterisk, $event) = @_; 
	printt 'Yeah! Event Type: ' . $event->{'Event'} ;
} 

sub sms_recieved_event { 
	my ($asterisk, $event) = @_; 
	printt $event->{Sender}.': ' . $event->{Content} ;
} 

sub sms_update_event { 
	my ($asterisk, $event) = @_; 
	printt $event->{ID}.': ' . $event->{Status} ;
	StoreMail::SMS::sms_send_status($event->{ID}, $event->{Status});
	print " status updated";
} 

sub do_hangup { 
	my ($asterisk, $event) = @_; 
	printt 'Channel ' . $event->{'Channel'} . ' Hungup because ' . $event->{'Cause-txt'} ;
} 

EV::loop;

print "end";
#$gateway->send('040255245', 'asdjasdkjasdkjaksjkjjddddddddddds ydfv dgf sgs dfsgdgfs sdfg sdfgsdfg josiodsjipdspdposojfdsp sdjofpsdj dos fjsdpofjpsdofjsp jspdfoj spdoj posdjf jdspoj poj poj dfjsosdpjpoj dfspoj dsjodsojdfsposdoj djsopsdj poj jsodpfoj posdofjposdjf jopsdjf pojsdpfoj spsdofj END', 'Primerjam');
#$gateway->send('040255245', 'Čžš znaki da vidmo', 'Primerjam');
#$gateway->send('5', 'Krneki stevilka', 'Primerjam');
#StoreMail::SMS::send_queue($gateway, 2);


#print $content;

=cut

=Telnet

my $last_event = '';
while(1){
	my $s = $gateway->check_slot_status(2)->{CMD};
	my $event = "Last: ".$s->{'Last event'}." State: ".$s->{'State'};
	printt $last_event if $last_event ne $event;
	$last_event = $event;
	sleep(0.1);
}

my $action = $gateway->check_sms(); 
print to_json $action;

exit(1);

my $action = $gateway->check_slot_status(2); 
print to_json $action;

#my $action = $gateway->command('gsm show spans'); 


print to_json $action;

my $action = $gateway->check_slot_status(2); 
print to_json $action;
sleep(2);

my $action = $gateway->check_slot_status(2); 
print to_json $action;
sleep(10);

my $action = $gateway->check_slot_status(2); 
print to_json $action;
 
=cut


=Flow

{
 "Privilege" : "SMSCommand",
 "CMD" : [
 "D-channel: 2",
 "Status: Power on, Provisioned, Up, Active,Standard",
 "Type: CPE",
 "Manufacturer: SIMCOM_Ltd",
 "Model Name: SIMCOM_SIM800",
 "Model IMEI: 862951028263961",
 "Model CBAND: DCS_MODE,ALL_BAND",
 "Revision: 1308B05SIM800M32_20140625_1100",
 "Network Name: VEGA",
 "Network Status: Registered (Home network)",
 "Signal Quality (0,31): 19",
 "SIM IMSI: 293700203101881",
 "SIM SMS Center Number: +38670007007",
 "Send SMS Center Number: Undefined",
 "Last event: Hangup",
 "State: READY",
 "Last send AT: ATH\\r\\n"
 ],
 "COMPLETED" : 1,
 "Response" : "Follows",
 "GOOD" : 1,
 "ActionID" : "2"
}


{
 "COMPLETED" : 1,
 "CMD" : [],
 "Privilege" : "SMSCommand",
 "ActionID" : "3",
 "GOOD" : 1,
 "Response" : "Follows"
}


{
 "CMD" : [
 "D-channel: 2",
 "Status: Power on, Provisioned, Up, Active,Standard",
 "Type: CPE",
 "Manufacturer: SIMCOM_Ltd",
 "Model Name: SIMCOM_SIM800",
 "Model IMEI: 862951028263961",
 "Model CBAND: DCS_MODE,ALL_BAND",
 "Revision: 1308B05SIM800M32_20140625_1100",
 "Network Name: VEGA",
 "Network Status: Registered (Home network)",
 "Signal Quality (0,31): 19",
 "SIM IMSI: 293700203101881",
 "SIM SMS Center Number: +38670007007",
 "Send SMS Center Number: Undefined",
 "Last event: Hangup",
 "State: SMS SENDING",
 "Last send AT: AT+CMGF=0\\r\\n"
 ],
 "COMPLETED" : 1,
 "Privilege" : "SMSCommand",
 "GOOD" : 1,
 "ActionID" : "4",
 "Response" : "Follows"
}


{
 "Privilege" : "SMSCommand",
 "CMD" : [
 "D-channel: 2",
 "Status: Power on, Provisioned, Up, Active,Standard",
 "Type: CPE",
 "Manufacturer: SIMCOM_Ltd",
 "Model Name: SIMCOM_SIM800",
 "Model IMEI: 862951028263961",
 "Model CBAND: DCS_MODE,ALL_BAND",
 "Revision: 1308B05SIM800M32_20140625_1100",
 "Network Name: VEGA",
 "Network Status: Registered (Home network)",
 "Signal Quality (0,31): 19",
 "SIM IMSI: 293700203101881",
 "SIM SMS Center Number: +38670007007",
 "Send SMS Center Number: Undefined",
 "Last event: sms sending",
 "State: SMS SENT",
 "Last send AT: \u001a\\r\\n"
 ],
 "COMPLETED" : 1,
 "Response" : "Follows",
 "GOOD" : 1,
 "ActionID" : "5"
}


{
 "Response" : "Follows",
 "GOOD" : 1,
 "ActionID" : "6",
 "Privilege" : "SMSCommand",
 "COMPLETED" : 1,
 "CMD" : [
 "D-channel: 2",
 "Status: Power on, Provisioned, Up, Active,Standard",
 "Type: CPE",
 "Manufacturer: SIMCOM_Ltd",
 "Model Name: SIMCOM_SIM800",
 "Model IMEI: 862951028263961",
 "Model CBAND: DCS_MODE,ALL_BAND",
 "Revision: 1308B05SIM800M32_20140625_1100",
 "Network Name: VEGA",
 "Network Status: Registered (Home network)",
 "Signal Quality (0,31): 14",
 "SIM IMSI: 293700203101881",
 "SIM SMS Center Number: +38670007007",
 "Send SMS Center Number: Undefined",
 "Last event: SMS send OK",
 "State: READY",
 "Last send AT: \u001a\\r\\n"
 ]
}

=cut

=Mechanize

use WWW::Mechanize::PhantomJS;
my $mech = WWW::Mechanize::PhantomJS->new();
my $filename = 'content.html';

my $url = 'http://192.168.10.68/cgi/WebCGI?1000';
my $data = {
	username => 'admin',
	secret => 'PlG3O|W4OVSz\VS6[VHl\lWy[Vi6OoG6\lDlPY[4QFK?',
};

my $response = $mech->post( $url, params => $data );
my $content = $response->decoded_content();
$mech->save_content( 'login.html' );

$mech->get( 'http://192.168.10.68/cgi/WebCGI?15000' );
$mech->save_content( 'sms.html' );

$mech->get( 'http://192.168.10.68/cgi/WebCGI?7040' );
$mech->save_content( 'call.html' );

$data = {
	updatetype => '0',
	extensions => '',
	trunk => 'All',
	duration => '',
	billable => '',
	disposition => '',
	communicationtype => '',
	begindate => '13 Apr 2016',
	enddate => '13 Apr 2016',
	startindex => '1',
	filtercount => '25',
};
$response = $mech->post( 'http://192.168.10.68/cgi/WebCGI?7043', params => $data );
$mech->save_content( $filename );
#my $content = $response->decoded_content();

=cut