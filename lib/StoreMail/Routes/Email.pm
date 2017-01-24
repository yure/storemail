package StoreMail::Routes::Email;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use StoreMail::Helper;
use Encode;
use Try::Tiny;

prefix '/:domain/email';



get '/bounced/:email' => sub {
	my $email = param('email');
	return 0 unless $email;
	
	my $blocked_record = schema->resultset('EmailBlacklist')->find({email => $email});
	if($blocked_record){
		return 1 if $blocked_record->type eq 'bounce';
	}
	return 0;
};


1;