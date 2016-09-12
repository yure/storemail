package StoreMail::Helper;
use Dancer ':syntax';

our $VERSION = '0.1';

use POSIX qw(strftime);
use Cwd qw/realpath/;
use Exporter; # gives you Exporter's import() method directly
our @ISA = qw(Exporter);
our @EXPORT = qw(
domain_setting 
trim extract_email 
extract_emails 
email_str
logfile
printt
extract_phone
file_exists
local_root_path
files_in_dir
); # symbols to export on request
use Encode;
my $appdir = realpath( "$FindBin::Bin/..");

sub printt { 
	my($txt) = @_;
	$|++;
	print "\n".(strftime '%d.%m.%y %H:%M:%S', gmtime())." | $txt"; 
}


sub trim {	
	my $str = shift; $str =~ s/^\s+|\s+$//g if $str; return $str;
}


sub domain_setting {
	my ($domain, $var) = @_;
	return undef unless $var;
	return config->{domains}->{$domain}->{$var} if defined config->{domains} and defined config->{domains}->{$domain} and defined config->{domains}->{$domain}->{$var};
	return config->{$var};
}

sub extract_email {
	my $str = shift;
	return undef unless $str;
	$str = decode("MIME-Header", $str);
	my ($name, $email) = $str =~ /(.*?)<(.*?)>/s;
	$email = $str unless $email;
	$name = trim($name);
	$name = undef if defined $name and $name eq '';
	return (trim($name), trim($email));
}

sub extract_emails {
	my $arg = shift;
	return () unless $arg;
	my @emails;
	$arg = [$arg] unless ref $arg eq 'ARRAY';
	    for my $raw_emails ( @{$arg} ){
		    for my $raw_email ( split ',', $raw_emails ){
		    	my ($name, $email) = extract_email($raw_email);
		    	push @emails, {name => $name, email => $email};
		    }
	    }
	return @emails;
}


sub email_str {
	my ($name, $email) = @_;
	return  $name ? encode("MIME-Q",$name)." <".$email.">" : $email; 
}

sub fh {
	my $logfilepath = shift;
	binmode STDOUT, ":utf8";
	# Set up main log
	open ( STDOUT, ">>$logfilepath" );
	open ( STDERR, '+>&STDOUT' );
	$| = 1; # Turn on buffer autoflush for log output
	select( STDOUT );
}

sub logfile {
	my $name = shift;
	fh("logs/$name.log");
}

sub extract_phone {
	my $str = shift;
	$str =~ s/\+/00/g;	
	$str =~ s/[^0-9]//g;
	return $str;
}


sub local_root_path {
	my $file = shift;
	return "$appdir/public/$file";	
}


sub file_exists {
	my $dancer_path = shift;
	return 1 if -e local_root_path $dancer_path;
	return 0;
}


sub files_in_dir {
	my $dir = shift;
	my @files;
	opendir(DIR, $dir) or return @files;

    while (my $file = readdir(DIR)) {
        next unless $file;
    	next if (-d "$dir/$file"); # Skip dirs
        next if ($file =~ m/^\./); # Use a regular expression to ignore files beginning with a period
		push @files, $file;
    }
    closedir(DIR);
    return @files;
}

true;
