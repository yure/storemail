#!/usr/bin/env perl
use Dancer ':script';
use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBIx::Class::DeploymentHandler;

my $dh = DBIx::Class::DeploymentHandler->new({ 
	schema => schema, 
	databases => 'MySQL',
	sql_translator_args => { add_drop_table => 0 }, 
});
 
my ($from, $to) = @ARGV;

$dh->prepare_deploy;
$dh->prepare_upgrade({ from_version => $from, to_version => $to});

print "Done.\n"