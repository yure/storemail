#!/usr/bin/env perl
# get_gmail.pl
use Dancer ':script';

use StoreMail::Helper;
use StoreMail::APIConversationImport;

my $lock = one_instance() or exit;

my $appdir = config->{appdir};
my $last_id_file = "$appdir/conversation_import_last_modified.txt";

sub set_last_modified {
	my $time = shift;
	open(my $fh, '>', $last_id_file) or die "Could not open file '$last_id_file' $!";
	print $fh $time;
	close $fh;
}


sub get_last_modified {
	open(my $fh, '<:encoding(UTF-8)', $last_id_file) or return 1;
	my $row = <$fh>;
	close $fh;
	return $row;
}


my $start_time = time;
my $last_modified = get_last_modified();
StoreMail::APIConversationImport::import_all($last_modified);     
set_last_modified($start_time);
print '.';


