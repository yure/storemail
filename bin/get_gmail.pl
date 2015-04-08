#!/usr/bin/env perl
# get_gmail.pl
use Dancer ':script';

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Servicator::Email;
use Servicator::Message;
use MIME::QuotedPrint::Perl;
use MIME::Base64;
use Email::MIME;
use Time::ParseDate;
use DateTime;
use Try::Tiny; 
use Encode qw(decode);
use File::Path qw(make_path remove_tree);
use FindBin;
use Cwd qw/realpath getcwd/;
use Getopt::Long;
use Proc::Daemon;
use File::Spec::Functions;
use Digest::MD5 qw(md5_hex);
sub trim {	my $str = shift; $str =~ s/^\s+|\s+$//g if $str; return $str;}
my ($imap, $initial, $appdir, $logfile);
sub logt { 
	my($txt) = @_;
	open(my $FH, '>>', catfile(getcwd(), $logfile)); 
	$|++; print $FH "\n".localtime().' | '.$txt;
	close $FH;
}
sub logi { 
	my($txt) = @_;
	open(my $FH, '>>', catfile(getcwd(), $logfile)); 
	$|++; print $FH $txt;
	close $FH;
}

$logfile = "log.txt";

sub fetch_all {	
	my $gmail = config->{gmail};
	for my $account_name (keys config->{gmail}->{accounts}){
		logt "- Account $account_name: ";
		my $account = config->{gmail}->{accounts}->{$account_name};
		$imap = log_in($account);
		unless($imap){
			logt 'Unable to log in';
			next;
		}
		$imap->Peek(1);
		$imap->Uid(1);
			
		$imap->select('INBOX') or die "Select INBOX error: ", $imap->LastError, "\n";
		my @inbox = $imap->messages;
		my @inbox_sorted = $imap->sort('Date', 'UTF-8', 'ALL');
		logi "Inbox: ";
		process_emails(\@inbox, 'i', $account);

		$imap->select('[Gmail]/Sent Mail') or die "Select INBOX error: ", $imap->LastError, "\n";;
		my @outbox = $imap->messages;
		logi "Sent mail: ";
		process_emails(\@outbox, 'o', $account);
			
	}
	die 'Inital import completed' if $initial;
=asd
	if($sleep){
		logt "Waiting $sleep sec\n----------------------\n\n";
		sleep($sleep);
	}
	else {
		last;
	}
=cut
}


sub log_in {
	my $account = shift;
	return Mail::IMAPClient->new(
			Server   => $account->{host},
			User     => $account->{username},
			Password => $account->{password},
			Ssl      => $account->{ssl},
			Port     => $account->{port},
		);
		
}

sub process_emails {
	my ($messages, $direction, $account) = @_;
	
	# Reverse list and keep adding until you find message in db
	for my $mail_id ($initial ? @$messages : reverse @$messages) {
		try {
			no warnings 'exiting';
			my $headers = $imap->parse_headers( $mail_id, "Date", "Subject", "To", "From" );
			my $all = $imap->parse_headers( $mail_id, "ALL");
			
			
			# ID
			my $message_id;
			$message_id = trim $all->{'Message-ID'}[0] if $all->{'Message-ID'};
			$message_id = trim $all->{'Message-Id'}[0] if $all->{'Message-Id'};
			$message_id = to_dumper $all unless $message_id;
			$message_id = md5_hex $message_id;
	
			# End if already exists
			unless($initial){
				last if schema->resultset('Message')->find({source => $account->{username}, message_id => $message_id});				
			} else {
				if (schema->resultset('Message')->find({source => $account->{username}, message_id => $message_id})){
					logi '.';
					next;
				}
			}
	
			# From
			my $from = $headers->{From}[0];
	
			# To
			my (@to_email) = split ',', $headers->{To}[0] if defined $headers->{To}[0];
	
			# Subject
			my $subject = decode("UTF-8", $headers->{Subject}[0]);
	
			# Datetime
			my $epoch = parsedate($headers->{Date}[0]);
			my $datetime = DateTime->from_epoch( epoch => $epoch ) if $epoch;
	
			# Message body
			my $struct;
			try{
				$struct = $imap->get_bodystructure($mail_id);				
			}
			catch {
				$imap = log_in($account);
				$struct = $imap->get_bodystructure($mail_id);				
			};
			
			# Body
			my $body = extract_body($struct, $imap, $mail_id, 'PLAIN');
			my $raw_body;
			unless( $body){
				$raw_body = extract_body($struct, $imap, $mail_id, 'HTML') ;
				$body = clean_html($raw_body);
			}
			
			$body = decode_qp($body);
			$body = decode("UTF-8", $body);
	
	
			# New message	
			my $message = Servicator::Message::new_message(	
				domain => $account->{domain} || config->{domain},			
				from => $from,
				to   => \@to_email,
				body         => $body,
				body_type         => $raw_body ? 'html' : 'plain',
				raw_body         => $raw_body,
				subject => $subject,
				direction => $direction,
				date => $datetime->ymd." ".$datetime->hms,
				message_id => $message_id,
				source => $account->{username},
				tags => 'primejam,mass-mail,someTag',
			);
			
			if($message){
		
	
				# Attachments
				my $mail_str = $imap->message_string($mail_id);
				my $dir = "$appdir/public/attachments/".$message->id;
				Email::MIME->new($mail_str)->walk_parts(sub {
					my($part) = @_;
			  		return unless defined $part->content_type and $part->content_type =~ /\bname="([^"]+)"/;  # " grr...
			  		system( "mkdir -p $dir" ) unless (-e $dir); 
					my $name = "$dir/$1";
					#logt "$0: writing $name...\n";
					open my $fh, ">", $name or die "$0: open $name: $!";
					#logt $fh $part->content_type =~ m!^text/! ? $part->body_str : $part->body or die "$0: logt $name: $!";
					close $fh or warn "$0: close $name: $!";
				});
				logi '['.$message->id.": ".$message->frm.", ".$message->date.'] ';
				
			}
			catch {
				logt "    Fetching email with id $mail_id was not successfull!!!";
			}
		}
	}
}

sub clean_html {
	my $body = ''.shift;
	$body =~ s/<style(.+?)<\/style>//smg; # Remove style tag
	return $body;	
}

sub clean_body {
	my $body = shift;
	
#	return $body; #Untill we cover all cases, do noting
	
	my ($clean_body, $wanted, $mailId);
	$body = decode("UTF-8",decode_qp($body));
	
	#my $from = "";
	#my $to = "\r\n";
	#($mailId) = $body =~ /$from(.*?)$to/s;

	#$from = "\r\n\r\n";
	#$to = $mailId;
	
	# Remove all from breake text on 
	#my $from = '';
	#my $to = substr(Servicator::Email::email_break_text, 0, -1); # Decoding can loose last char...
	#($wanted) = $body =~ /$from(.*?)$to/s;
	
	
	
	$wanted = $body;
	if($wanted){
		$wanted = remove_gmail_code($wanted);
		$wanted = remove_outlook_code($wanted);
		$wanted = trim($wanted);
		$clean_body = $wanted if $wanted;
	}
	
	
	
	# If no text, try bottom post
	unless($clean_body){
		
	}
	
	# Remove 
	
	return $clean_body;
}


sub remove_gmail_code {
	my $body = shift;
	my $clean_body;
	my $gmail_id;
	
	# Check if gmail format
	my $first_row;
	($first_row) = $body =~ /(--.{28}?)\n/s;
	return $body unless $first_row;
	
	# Remove On Thu, May 29, 2014 at 9:01 AM, John <name@email.com> wrote:
	# Remove --001a1134d7c0f749fe04fa848617 Content-Type: text/plain; charset=UTF-8
	
	#my $from = "--(.+?)\nContent-Type: (.+?); charset=(.+?)\n";
	my $from = "\n\n";
	my $to = "\nOn(.+?)at(.+?),(.+?)<(.+?)@(.+?)> wrote:";
	($clean_body)= $body =~ /$from(.*?)$to/s;	
	
	return $clean_body ? $clean_body : $body;
}


sub remove_outlook_code {
	my $body = shift;
	my $clean_body;
	my $gmail_id;
	# Remove On Thu, May 29, 2014 at 9:01 AM, John <name@email.com> wrote:
	# Remove --001a1134d7c0f749fe04fa848617 Content-Type: text/plain; charset=UTF-8
	
	my $from = "";
	my $to = "\nOn(.+?),(.+?) wrote:";
	($clean_body)= $body =~ /$from(.*?)$to/s;	
	
	return $clean_body ? $clean_body : $body;
}


sub extract_body  {
	my ($struct, $imap, $msg, $subtype) = @_;
	if ($struct->bodytype eq "MULTIPART") {
		for my $part ($struct->bodystructure()) {
			return extract_body($part, $imap, $msg, $subtype);
		}
	}
	if (lc $struct->bodytype eq lc "TEXT" and lc $struct->bodysubtype eq lc $subtype) {
	   if (lc $struct->bodyenc eq "base64") {
	        return decode_base64($imap->bodypart_string($msg,$struct->id));
	        }
	   elsif (lc $struct->bodyenc eq lc "QUOTED-PRINTABLE" ) {
	        return $imap->bodypart_string($msg,$struct->id);
	        }
	   elsif (index(" -7bit- -8bit- -quoted-logtable- ",lc($struct->bodyenc)) !=-1  ) {
	        return $imap->bodypart_string($msg,$struct->id);
	        }
	}
	
	return "";
}

#-------- DAEMON STUFF --------

my $pf = catfile(getcwd(), 'pidfile.pid');
my $daemon = Proc::Daemon->new(
	pid_file => $pf,
	work_dir => getcwd()
);
# are you running?  Returns 0 if not.
my $pid = $daemon->Status($pf);
my $daemonize = 1;

GetOptions(
    'daemon!' => \$daemonize,
    "help"    => \&usage,
    "reload"  => \&reload,
    "restart" => \&restart,
    "start"   => \&run,
    "status"  => \&proc_status,
    "stop"    => \&stop,
    "init"    => \&init_import,
    ) or die $!;
exit(0);

sub stop {
        if ($pid) {
	        print "Stopping pid $pid...\n";
	        if ($daemon->Kill_Daemon($pf)) {
		        print "Successfully stopped.\n";
		        logt "Service stopped.";
	        } else {
		        print "Could not find $pid.  Was it running?\n";
	        }
         } else {
                print "Not running, nothing to stop.\n";
         }
}


sub proc_status {
	if ($pid) {
		print "Running with pid $pid.\n";
	} else {
		print "Not running.\n";
	}
}


sub run {
	if (!$pid) {
		print "Starting...\n";
		if ($daemonize) {
			# when Init happens, everything under it runs in the child process.
			# this is important when dealing with file handles, due to the fact
			# Proc::Daemon shuts down all open file handles when Init happens.
			# Keep this in mind when laying out your program, particularly if
			# you use filehandles.
			$daemon->Init;
		}

		logt "Service starting...";
		my $sleep = config->{sleep} || 10;
		while (1) {
            $appdir = realpath( "$FindBin::Bin/..");
			
			#my $sleep = $args{'--sleep'};
			$initial = undef; #$args{'-i'};
			logt "Starting initial import!" if $initial;
			
			die "Set some IMAP accounts in config!" unless config->{gmail} and config->{gmail}->{accounts};
			
            fetch_all();     
                        # this example writes to a filehandle every 5 seconds.
            logt "Sleeping $sleep seconds.";
			sleep $sleep;
		}
	} else {
		print "Already Running with pid $pid\n";
	}
}


sub init_import {
		print "Starting initial import...\n";
		$logfile = 'initial_import_log.txt';
		logt "Service starting...";
        $appdir = realpath( "$FindBin::Bin/..");
			
		$initial = 1; #$args{'-i'};
		logt "Starting initial import!" if $initial;
			
		die "Set some IMAP accounts in config!" unless config->{gmail} and config->{gmail}->{accounts};
		
        fetch_all();     
}


sub usage
{
    my ($opt_name, $opt_value) = @_;
    print "your usage text goes here...\n";
    exit(0);
}


sub reload
{
    my ($opt_name, $opt_value) = @_;
    print "reload process not implemented.\n";
}


sub restart
{
    my ($opt_name, $opt_value) = @_;
    &stop;
    &run;
}
