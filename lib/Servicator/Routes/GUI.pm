package Servicator::Routes::GUI;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBI;

our $VERSION = '0.1';

prefix '/:domain';

get '/gui/conversation/all' => sub {
    return template 'all.html', {domain => param('domain')};
};


get '/gui/conversation/:id' => sub {
    return template 'conversation.html', {domain => param('domain'), id => param('id')};
};


true;
