package StoreMail;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;

use DBI;


# API routes
get '**' => sub {
	content_type('application/json');
	pass;
};

use StoreMail::Auth;
use StoreMail::Routes::GUI;
use StoreMail::Routes::Message;
use StoreMail::Routes::Conversation;
use StoreMail::Routes::Provider;
use StoreMail::Routes::Tag;


our $VERSION = '0.1';

1;