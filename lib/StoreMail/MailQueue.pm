package StoreMail::MailQueue;
use Dancer ':syntax';

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Email;
use StoreMail::Message;
use StoreMail::Helper;
use MIME::QuotedPrint::Perl;
use Email::MIME;
use Encode qw(decode);
use File::Path qw(make_path remove_tree);
use FindBin;
use Cwd qw/realpath/;
use Getopt::Long;

my $appdir = realpath( "$FindBin::Bin/..");

my $redirect = undef;

sub send {
	my $args = {@_};
	my $messages = schema->resultset('Message')->search( {
		send_queue => 1,
		send_queue_sleep => {'<' => time()},
		send_queue_fail_count => {'<' => 6},
	}, {order_by => { -desc => 'date' }} );
	
	if (my $count = $messages->search( {},{columns => [qw/id/]} )->count() ) {
	
	
		while (my $message = $messages->next) {
			my $fc = $message->send_queue_fail_count;
			
			printt substr($message->subject, 0, 50). "\n" ."[".$message->frm." to " . join(', ', $message->toccbcc) . "] " . ($fc ? "[TRY ".($fc+1)."] " : '') .' | ';
			
			my ($status, $msg) = $message->send($args->{redirect});
			if($status){
				$message->send_queue(undef);
				$message->update;	
				$message->send(config->{storemail_catchall}) if config->{storemail_catchall};			
			}
			else {
				my $fail_count = $message->send_queue_fail_count;
				$message->send_queue_fail_count($fail_count+1);
				$message->send_queue_sleep(time() + 10 ** $fail_count );
				$message->update;
			}
			print "$msg\n";
		}
	}
	else{
		# print ".";
	}
}

return 1;
