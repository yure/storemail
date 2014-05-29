package Mail::Email;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::Email;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Mail::IMAPClient;

#$str =~ s/$find/$replace/g;
prefix '/:domain';


sub email_break_text {return '===== WRITE YOUR REPLY ABOVE THIS LINE ====='};

#$imap->Peek(1); # Leave it unread

get '/checkmail' => sub {
	my $domain = "@" . param('domain');

	my $imap   = Mail::IMAPClient->new(
		Server   => config->{catch_all}->{host},
		User     => config->{catch_all}->{username},
		Password => config->{catch_all}->{password},
		Ssl      => config->{catch_all}->{ssl},
		Port     => config->{catch_all}->{post},
	);
	$imap->select('INBOX') or die "Select INBOX error: ", $imap->LastError, "\n";
	my @unread = $imap->unseen;
	
	unless (@unread){
		warn "No new emails: $@\n";
		return "no new";
	}
	
	debug "New email found. Processing...";

	#splice @unread, 5;
	for my $mail_id (@unread) {
		my $hashref = $imap->parse_headers( $mail_id, "Date", "Subject", "To", "From" );

		# TODO: weed out random mail

		# Conversation ID
		my $email;
		my $conv_id = $hashref->{To}[0];
		($conv_id)= $conv_id =~ /<(.*?)>/s;
		$conv_id =~ s/$domain//g;
		
		my $conversation = schema->resultset('Conversation')->find($conv_id.$domain);
		
		# Message body
		my $body = extract_body( $imap->body_string($mail_id) );
		
		my $b_struc = $imap->get_bodystructure($mail_id);

		# Sender
		my $sender_email = $hashref->{From}[0];
		($sender_email)= $sender_email =~ /<(.*?)>/s;
		
		# Check sender
		my $user_sender = $conversation->search_related('users', { email => $sender_email} )->first;
		return {error => 'Sender not found'} unless $user_sender;

		#$imap->subject($mail_id)

		Mail::Message::new_message(
			id         => $conv_id,
			domain     => param('domain'),
			sender_email     => $user_sender->email,
			recipients => $conversation->recipients($user_sender),
			body       => $body
		);
	}
	return "sent";
};

sub send_mail {
	my %mail = @_;
	$mail{sender} ||= "";
	$mail{recipients} ||= "";
	debug "Mail to ".join(", ", @{$mail{recipients}})." from $mail{sender}: $mail{body}";
	
	#my @recipients = split ",", $mail{recipients};
	for my $recipient (@{$mail{recipients}}) {
		my $msg = email {
			from    => $mail{sender},
			to      => $recipient->{name} . " <".$recipient->{email}.">",
			subject => $mail{subject},
			body    => wrap_body( $mail{body} ),

			#attach  => '/path/to/attachment',
		};
		warn $msg->{string} if $msg->{type} and $msg->{type} eq 'failure';
	}

	return undef;
}


sub wrap_body {
	my $body = shift;
	
	$body = Mail::Email::email_break_text.'
	
'.$body;
		
	return $body;
}

true;
