package StoreMail;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;

use DBI;

use StoreMail::Routes::GUI;

# API routes
get '**' => sub {
	content_type('application/json');
	pass;
};
use StoreMail::Routes::Message;
use StoreMail::Routes::Conversation;
use StoreMail::Routes::Provider;


our $VERSION = '0.1';

1;