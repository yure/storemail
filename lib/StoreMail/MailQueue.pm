#!/usr/bin/env perl
package StoreMail::MailQueue;
use Dancer ':script';

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Email;
use StoreMail::Message;
use MIME::QuotedPrint::Perl;
use Email::MIME;
use Encode qw(decode);
use File::Path qw(make_path remove_tree);
use FindBin;
use Cwd qw/realpath/;
use Getopt::Long;
sub printt { $|++; print "\n".localtime().' | '.shift }

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
	
		printt ("$count emails found. Processing..." . ($args->{redirect} ? 'with redirect to '.$args->{redirect}.' ...' : '') );
	
		while (my $message = $messages->next) {
			my $fc = $message->send_queue_fail_count;
			
			printt "[".$message->frm." to " . join(', ', $message->toccbcc) . "] " . ($fc ? "[TRY ".($fc+1)."] " : '') . $message->subject.' | ';
			
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
			print $msg;
		}
		print "\n"
	}
	else{
		print ".";
	}
}

return 1;
