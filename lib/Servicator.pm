package Servicator;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;

use DBI;

use Servicator::Routes::GUI;

# API routes
get '**' => sub {
	content_type('application/json');
	pass;
};
use Servicator::Routes::Message;
use Servicator::Routes::Conversation;
use Servicator::Routes::Provider;


our $VERSION = '0.1';

1;