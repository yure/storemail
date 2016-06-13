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
use StoreMail::Routes::Attachment;
use StoreMail::Routes::GUI;
use StoreMail::Routes::Message;
use StoreMail::Routes::Provider;
use StoreMail::Routes::Tag;
use StoreMail::Routes::Batch;
use StoreMail::Routes::Group;
use StoreMail::Routes::SendGrid;
use StoreMail::Routes::SMS;

our $VERSION = '0.1';

1;