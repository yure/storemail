package Servicator::Email;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::Email;
use Dancer::Plugin::DBIC qw(schema resultset rset);

prefix '/:domain';

sub email_break_text {return '===== WRITE YOUR REPLY ABOVE THIS LINE ====='};


sub send_mail {
	my %mail = @_;
	$mail{sender} ||= "";
	$mail{recipients} ||= "";
	debug "Mail to ".join(", ", map( $_->{email}, @{$mail{recipients}}))." from $mail{sender}: $mail{body}";
	
	#my @recipients = split ",", $mail{recipients};
	for my $recipient (@{$mail{recipients}}) {
		my $msg = email {
			from    => $mail{sender},
			to      => $recipient->{name} . " <".$recipient->{email}.">",
			subject => $mail{subject},
			body    => wrap_body( $mail{body} ),

			attach  => $mail{attachments} ? [$mail{attachments}] : undef,
		};
		warn $msg->{string} if $msg->{type} and $msg->{type} eq 'failure';
	}

	return undef;
}


sub wrap_body {
	my $body = shift;
	
	$body = Servicator::Email::email_break_text.'
	
'.$body;
		
	return $body;
}

true;
