package StoreMail::Routes::SendGrid;
use Dancer ':syntax';

use StoreMail::SendGrid;

prefix '/sendgrid';


post '/event' => sub {
	
	# Forward
	my $url = 'https://app.primerjam.si/sendgrid-webhook';
	my $req = HTTP::Request->new(POST => $url);
	$req->content_type('application/json');
	$req->content(request->body);
	
	my $ua = LWP::UserAgent->new; # You might want some options here
	my $res = $ua->request($req);
	
	debug "SendGrid event fwd FAILED" unless ( $res->code eq '200');
	
	# Save
	my $events = from_json request->body;
	
	for my $event_data (@$events){ 
		StoreMail::SendGrid::handle_event($event_data);
	}
	
	return 1; 
};


=Example JSON

# Faked 
	my $events = '[{
		"sg_message_id": "547u6zj",
		"email": "john.doe@sendgrid.com",
		"timestamp": 1337197600,
		"smtp-id": "<4FB4041F.6080505@sendgrid.com>",
		"event": "processed"
	}, {
		"sg_message_id": "7k64r5tj",
		"email": "john.doe@sendgrid.com",
		"timestamp": 1337966815,
		"category": "newuser",
		"event": "click",
		"url": "https://sendgrid.com"
	}, {
		"sg_message_id": "647kjr657",
		"email": "john.doe@sendgrid.com",
		"timestamp": 1337969592,
		"smtp-id": "<20120525181309.C1A9B40405B3@Example-Mac.local>",
		"event": "group_unsubscribe",
		"asm_group_id": 42
	}, {
		"sg_message_id": "ort678rcdt",
		"email": "john.doe@sendgrid.com",
		"timestamp": 1337966815,
		"event": "click",
		"url": "https://sendgrid.com",
		"userid": "1123",
		"template": "welcome"
	}, {
		"status": "5.0.0",
		"sg_event_id": "r6j78uji567i",
		"sg_message_id": "e5j67jured6u",
		"event": "bounce",
		"email": "email@example.com",
		"timestamp": 1249948800,
		"smtp-id": "<original-smtp-id@domain.com>",
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"reason": "500 No Such User",
		"type": "bounce",
		"asm_group_id": 1
	}, {
		"sg_event_id": "d567gh",
		"sg_message_id": "h7dd657",
		"email": "email@example.com",
		"timestamp": 1249948800,
		"smtp-id": "<original-smtp-id@domain.com>",
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"reason": "Bounced Address",
		"event": "dropped"
	}, {
		"email": "email@example.com",
		"timestamp": 1249948800,
		"ip": "255.255.255.255",
		"sg_event_id": "drtzj56",
		"sg_message_id": "ej57jre675zuhs54ew",
		"useragent": "Mozilla/5.0 (Windows NT 5.1; rv:11.0) Gecko Firefox/11.0 (via ggpht.com GoogleImageProxy)",
		"event": "open",
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"newsletter": {
			"newsletter_user_list_id": "10557865",
			"newsletter_id": "1943530",
			"newsletter_send_id": "2308608"
		},
		"asm_group_id": 1
	}, {
		"sg_event_id": "e5j6rzju5r6u",
		"sg_message_id": "j67k5rekji",
		"email": "email@example.com",
		"timestamp": 1249948800,
		"smtp-id": "<original-smtp-id@domain.com>",
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"event": "processed",
		"newsletter": {
			"newsletter_user_list_id": "10557865",
			"newsletter_id": "1943530",
			"newsletter_send_id": "2308608"
		},
		"asm_group_id": 1,
		"send_at": 1249949000
	}, {
		"sg_event_id": "ej57juiri6tz78kt78",
		"sg_message_id": "dtkjir567ui",
		"email": "email@example.com",
		"timestamp": 1249948800,
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"event": "spamreport",
		"asm_group_id": 1
	}, {
		"sg_message_id": "sendgrid_internal_message_id",
		"email": "email@example.com",
		"timestamp": 1249948800,
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"event": "unsubscribe",
		"asm_group_id": 1
	}, {
		"response": "400 Try again",
		"sg_event_id": "zkjugfki6785",
		"sg_message_id": "she554z4",
		"event": "deferred",
		"email": "email@example.com",
		"timestamp": 1249948800,
		"smtp-id": "<original-smtp-id@domain.com>",
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"attempt": "10",
		"newsletter": {
			"newsletter_user_list_id": "10557865",
			"newsletter_id": "1943530",
			"newsletter_send_id": "2308608"
		},
		"asm_group_id": 1,
		"ip": "127.0.0.1",
		"tls": "0",
		"cert_err": "0"
	}, {
		"sg_event_id": "asger4tg4es5hws34",
		"sg_message_id": "jmr654edrzghf6t5u5e",
		"ip": "255.255.255.255",
		"useragent": "Mozilla/5.0 (iPhone; CPU iPhone OS 7_1_2 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D257 Safari/9537.53",
		"event": "click",
		"email": "email@example.com",
		"timestamp": 1249948800,
		"url": "http://yourdomain.com/blog/news.html",
		"url_offset": {
			"index": 0,
			"type": "html"
		},
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"newsletter": {
			"newsletter_user_list_id": "10557865",
			"newsletter_id": "1943530",
			"newsletter_send_id": "2308608"
		},
		"asm_group_id": 1
	}, {
		"status": "5.0.0",
		"sg_event_id": "xdre5zh6r7kjre567u",
		"sg_message_id": "d456ju5euj5e67jedr",
		"event": "bounce",
		"email": "email@example.com",
		"timestamp": 1249948800,
		"smtp-id": "<original-smtp-id@domain.com>",
		"unique_arg_key": "unique_arg_value",
		"category": ["category1", "category2"],
		"newsletter": {
			"newsletter_user_list_id": "10557865",
			"newsletter_id": "1943530",
			"newsletter_send_id": "2308608"
		},
		"asm_group_id": 1,
		"reason": "500 No Such User",
		"type": "bounce",
		"ip": "127.0.0.1",
		"tls": "1",
		"cert_err": "0"
	}

]';

=cut

1;
