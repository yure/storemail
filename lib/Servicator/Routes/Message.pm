package Servicator::Routes::Message;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Dancer::Plugin::DBIC qw(schema resultset rset);

prefix '/:domain';


get '/message/all' => sub {
    my @messages = schema->resultset('Message')->search()->all;
    return to_json [map { {$_->get_columns} } @messages];
};


get '/message/:id' => sub {
    my $message = schema->resultset('Message')->find(param('id'));
    return to_json {$message->get_columns};
};

1;