package StoreMail::Email;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::Email;

prefix '/:domain';

sub email_break_text {return '===== WRITE YOUR REPLY ABOVE THIS LINE ====='};


sub wrap_body {
	my $body = shift;
	
	$body = StoreMail::Email::email_break_text.'
	
'.$body;
		
	return $body;
}

true;
