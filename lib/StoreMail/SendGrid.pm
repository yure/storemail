package StoreMail::SendGrid;
use Dancer ':syntax';

use Dancer::Plugin::DBIC qw(schema resultset rset);


sub handle_event {
	my $event_data = shift;
	
	my $event = schema->resultset('SendGridEvent')->update_or_create({
		type => $event_data->{event},
		email => $event_data->{email},
		timestamp => $event_data->{timestamp},
		sendgrid_id => $event_data->{sg_message_id},
		data => $event_data,
	});
	
	if($event_data->{event} eq 'bounce' or $event_data->{event} eq 'dropped'){
		my $type;
		$type = $event_data->{type};
		$type ||= $event_data->{event};
		
		schema->resultset('EmailBlacklist')->update_or_create({
			email => $event_data->{email},
			timestamp => $event_data->{timestamp},
			reason => substr($event_data->{reason}, 0, 255),
			type => $type,
		});
		
	}
	
}

1;
