#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::Helper;
use File::Copy qw(copy move);
$|= 1;

my $last_id = shift @ARGV || 0;


my $messages = schema->resultset('Message')->search({id => {'>' => $last_id}}, {columns => ['id'], order_by => 'id'});

while (my $message_id_only = $messages->next){
	my $message = schema->resultset('Message')->find($message_id_only->id);
	
	my @files = $message->attachments;
	print ".";
	next unless @files;
	my $to_dir = local_root_path $message->attachment_hash_path;
	system( "mkdir -p $to_dir" ) unless (-e $to_dir);  

	for my $file (@files){
		print "_";
		next unless $file;
		print "f";
		my $from = local_root_path $message->attachment_local_path($file);
		my $to = "$to_dir/$file";
		next if $from eq $to;
		printt $message_id_only->id.": $from -> $to";
		copy "$from", "$to";		
    }
	
}

print "Done.\n";
