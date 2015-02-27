use Dancer ':script';

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Servicator::Email;
use Servicator::Message;
use MIME::QuotedPrint::Perl;
use Email::MIME;
use Encode qw(decode);
use File::Path qw(make_path remove_tree);
use FindBin;
use Cwd qw/realpath/;
my $appdir = realpath( "$FindBin::Bin/..");

my %args = @ARGV;

my $sleep = $args{'--sleep'} || 5;

while(1){
	
	my $messages = schema->resultset('Message')->search( {send_queue => 1}, {order_by => '-date'} );

	if (my $count = $messages->count) {

		debug "$count emails found. Processing...";
	
		#splice @unread, 5;
		while (my $message = $messages->next) {
			if($message->send){
				$message->send_queue(undef);
				$message->update;
			}
		}
	}
	else{
		warn "No new emails\n";
	}

	sleep($sleep);
}