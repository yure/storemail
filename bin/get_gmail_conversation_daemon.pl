#!/usr/bin/env perl
# get_gmail.pl
use Dancer ':script';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Helper;
use StoreMail::ImapFetchConversationImport;
use Try::Tiny; 
use Cwd qw/realpath getcwd/;
use Getopt::Long;
use Proc::Daemon;
use Dancer::Plugin::Email;
use File::Spec::Functions;



#-------- DAEMON STUFF --------
my $appdir = config->{appdir};
my $dir = config->{pid_dir} ? catfile(config->{pid_dir}, 'storemail') : "$appdir/run";
system( "mkdir -p $dir" ) unless (-e $dir);
my $pf = catfile($dir, "get_gmail_conversation.pid");

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
    "run"   => \&run_once,
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
		        printt "Service stopped.\n";
	        } else {
		        print "Could not find $pid.  Was it running?\n";
	        }
         } else {
                print "Not running, nothing to stop.\n";
         }
	$pid = $daemon->Status($pf);
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
		logfile('get_gmail_conversation');
			$daemon->Init;
		}
		
		print "Service starting...";
		logfile('get_gmail_conversation');
		my $sleep = 5 || config->{get_gmail_sleep} || 10;
		die "Set some IMAP accounts in config!" unless config->{gmail} and config->{gmail}->{accounts};
		while (1) {
			
			
			try{
	            StoreMail::ImapFetchConversationImport::fetch_all();     
			}
			catch {
				email {
			        from    => 'get.gmail@informa.si',
			        to      => config->{admin_email},
			        subject => 'Get Gmail error',
			        body    => $_,
			    };
			};			
                        # this example writes to a filehandle every 5 seconds.
            printt "Sleeping $sleep seconds.";
			sleep $sleep;
		}
	} else {
		print "Already Running with pid $pid\n";
	}
}


sub init_import {
		print "Starting initial import...\n";
		logfile('get_gmail_init_conversation');
		printt "Service starting...";
			
		printt "Starting initial import!";
			
		die "Set some IMAP accounts in config!" unless config->{gmail} and config->{gmail}->{accounts};
		
        StoreMail::ImapFetchConversationImport::fetch_all(initial => 1);     
}


sub run_once {
		print "Running import once...\n";
		logfile('get_gmail_conversation');
			
		printt "Running import once!";
		die "Set some IMAP accounts in config!" unless config->{gmail} and config->{gmail}->{accounts};
		
        StoreMail::ImapFetchConversationImport::fetch_all();     
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
