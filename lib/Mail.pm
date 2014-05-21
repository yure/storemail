package Mail;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBI;

use Mail::GUI;

our $VERSION = '0.1';

get '**' => sub {
	content_type('application/json');
	pass;
};

get '/' => sub {
	my @drivers = map "$_\n", DBI->available_drivers;
    return to_dumper \@drivers;
};


get '/message/all' => sub {
    my @messages = schema->resultset('Message')->search()->all;
    return to_json [map { {$_->get_columns} } @messages];
};


get '/message/:id' => sub {
    my $message = schema->resultset('Message')->find(params->{id});
    return to_json {$message->get_columns};
};


get '/conversation/all' => sub {
    my @conversations = schema->resultset('Conversation')->search()->all;
    return to_json [map { {$_->get_columns} } @conversations];
};


get '/conversation/:id' => sub {
    my $conversation = schema->resultset('Conversation')->find(params->{id});
    return to_json {
    	subject => $conversation->subject,
    	messages => [map { {$_->get_columns} } $conversation->messages]
    };
};


post '/conversation/:id' => sub {
	my $form_data = params("body");
    my $message = schema->resultset('Message')->create({
    	conversation_id => params->{id},
    	from_email => $form_data->{from_email},
    	body => $form_data->{body},
    });
    
    return to_json {
    	error => undef
    };
};

true;
