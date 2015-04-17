#!/usr/bin/env perl
use Dancer ':script';
use Cwd qw/realpath getcwd/;
use Getopt::Long;
use Proc::Daemon;
use File::Spec::Functions;
use Try::Tiny;

my $logfile = "mail_queue_log.txt";
my $redirect;
my $retry_sleep = 30;
my $retry_total_time = 60*15;
my $retry_time = 0;

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


sub service {
	open(my $FH, '>>', catfile(getcwd(), $logfile));
	select($FH);
	
	try{
		require StoreMail::MailQueue;
		StoreMail::MailQueue::send(redirect => $redirect);	
		$retry_time = 0;	
	}
	catch {
		$retry_time += $retry_sleep;
		logt "Error while trying to run. Waiting $retry_sleep seconds.";
		if($retry_time < $retry_total_time){
			sleep $retry_sleep;
			service();
		}
		else {
			logt "Total time for retrying is up. Exiting.";
			die "Total time for retrying is up. Exiting.";
		}
	};

	sleep (config->{mail_queue_sleep} || 3);
	select(STDOUT);
}

#logt `bin/mail_queue.pl`;
#exit(0);

#-------- DAEMON STUFF --------

my $pf = catfile(getcwd(), 'mail_queue_daemon.pid');
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
    "redirect=s"    => \$redirect,
    "logfile=s"    => \$logfile,
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
		print "With redirect to $redirect...\n" if $redirect;
		if ($daemonize) {
			# when Init happens, everything under it runs in the child process.
			# this is important when dealing with file handles, due to the fact
			# Proc::Daemon shuts down all open file handles when Init happens.
			# Keep this in mind when laying out your program, particularly if
			# you use filehandles.
			$daemon->Init;
		}
		logt "Service starting...";
		logt "With redirect to $redirect..." if $redirect;
		while(1){
			service();
		}
	} else {
		print "Already Running with pid $pid\n";
	}
}


sub run_once {
	
	logt "Script starting...";
	logt "With redirect" if $redirect;
	service();
	
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
