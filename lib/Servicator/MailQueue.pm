#!/usr/bin/env perl
package Servicator::MailQueue;
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
use Getopt::Long;
sub printt { $|++; print "\n".localtime().' | '.shift }

my $appdir = realpath( "$FindBin::Bin/..");

my $redirect = undef;

sub send {
	my $args = {@_};
	my $messages = schema->resultset('Message')->search( {send_queue => 1}, {order_by => '-date'} );
	
	if (my $count = $messages->count) {
	
		printt "$count emails found. Processing..." . ($args->{redirect} ? 'with redirect to '.$args->{redirect}.' ...' : '');
	
		#splice @unread, 5;
		while (my $message = $messages->next) {
			if($message->send($args->{redirect})){
				$message->send_queue(undef);
				$message->update;
			}
		}
		print 'Done.\n'
	}
	else{
		print ".";
	}
}

return 1;