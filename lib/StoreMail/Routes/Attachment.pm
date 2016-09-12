package StoreMail::Routes::Attachment;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Encode;
use Try::Tiny;

prefix '/:domain';



get '/file/:h1/:h2/:h3/:h4/:h5/:h6/:h7/:h8/:h9/:h10/:h11/:h12/:h13/:h14/:h15/:h16/:control_hash/:file' => sub {
    my $hash = join('', param('h1'),param('h2'),param('h3'),param('h4'),param('h5'),param('h6'),param('h7'),param('h8'),param('h9'),param('h10'),param('h11'),param('h12'),param('h13'),param('h14'),param('h15'),param('h16'));
    return undef unless param('control_hash');
    find_and_return_file(param('file'), $hash, param('control_hash'));    
};


get '/attachments/:h1/:h2/:h3/:h4/:h5/:h6/:h7/:h8/:h9/:h10/:h11/:h12/:h13/:h14/:h15/:h16/:file' => sub {
    my $hash = join('', param('h1'),param('h2'),param('h3'),param('h4'),param('h5'),param('h6'),param('h7'),param('h8'),param('h9'),param('h10'),param('h11'),param('h12'),param('h13'),param('h14'),param('h15'),param('h16'));   
    find_and_return_file(param('file'), $hash);
};


sub find_and_return_file {
	my ($file, $hash, $control_hash) = @_;
	
    my $message = schema->resultset('Message')->find({ message_id => $hash });
    return 'message not found!' unless $message;
    
    # Second layer of auth
    if($control_hash){
    	return undef unless $control_hash eq $message->id_hash_two_pass;
    }
    
    send_file($message->attachment_local_path($file));

}




1;