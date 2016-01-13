package StoreMail::Routes::GUI;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBI;

our $VERSION = '0.1';

prefix '/:domain';

get '/gui/conversation/all' => sub {
	content_type('text/html');
    return template 'all.html', {domain => param('domain')};
};


get '/gui/conversation/:id' => sub {
	content_type('text/html');
    return template 'conversation.html', {domain => param('domain'), id => param('id')};
};

get '/gui/provider/:comma_separated_emails' => sub {
	content_type('text/html');
	my @emails = map { s/\s*(\S+)\s*/$1/; $_ } split ',', param('comma_separated_emails');
	#return to_dumper \@emails;
    return template 'provider.html', {title=> 'Provider', domain => param('domain'), from => param('comma_separated_emails')};
};

get '/gui/send-batch' => sub {
	content_type('text/html');
    return template 'batch_send.html', {title=> 'Provider', domain => param('domain')};
};


true;
