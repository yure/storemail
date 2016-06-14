#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::Auth;
require LWP::Simple;

my $domain = shift @ARGV;
my $arg = shift @ARGV;

print "\nDomain: $domain\n";

if($arg and $arg eq '-1'){
	print StoreMail::Auth::token_yesterday($domain)
}
else {
	print StoreMail::Auth::token_today($domain);
}


print "\n";
