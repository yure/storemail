package StoreMail::Routes::Attachment;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Encode;
use Try::Tiny;
use Cwd qw/realpath/;
my $appdir = realpath( "$FindBin::Bin/..");

prefix '/:domain';


get '/attachments/:h1/:h2/:h3/:h4/:h5/:h6/:h7/:h8/:h9/:h10/:h11/:h12/:h13/:h14/:h15/:h16/:file' => sub {
    
    my $hash = join('', param('h1'),param('h2'),param('h3'),param('h4'),param('h5'),param('h6'),param('h7'),param('h8'),param('h9'),param('h10'),param('h11'),param('h12'),param('h13'),param('h14'),param('h15'),param('h16'));
    my $message = schema->resultset('Message')->find({ message_id => $hash });
    return 'message not found!' unless $message;
    my $path_id = $message->attachment_id_dir;
    my $file_path = "attachments/$path_id/" . param('file');
    debug "Exists" if -e $file_path; 
    return send_file($file_path);
};


1;