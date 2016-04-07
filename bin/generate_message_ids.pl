#!/usr/bin/env perl
use Dancer ':script';
use Dancer::Plugin::DBIC qw(schema resultset rset);

my $domain = shift @ARGV;
my $arg = shift @ARGV;

my $message_no_hash = schema->resultset('Message')->search({message_id => undef});

$|= 1;

while (my $message = $message_no_hash->next){
	print $message->id.' ';
	$message->message_id($message->id_hash);
	$message->update;
}

print "\n";