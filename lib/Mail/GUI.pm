package Mail::GUI;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBI;

our $VERSION = '0.1';



get '/gui/conversation/all' => sub {
    return template 'all.html', {};
};


get '/gui/conversation/:id' => sub {
	
    return template 'con.html', {id => params->{id}};
};



true;
