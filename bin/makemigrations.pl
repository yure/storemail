#!/usr/bin/env perl
use Dancer ':script';
use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBIx::Class::DeploymentHandler;

my $arg = {map {$_ => 1} @ARGV};

my $dh = DBIx::Class::DeploymentHandler->new({ 
	schema => schema, 
	databases => 'MySQL',
	force_overwrite => $arg->{force},
	sql_translator_args => { add_drop_table => 0, }, 
});
 

$dh->prepare_deploy;
$dh->prepare_upgrade();

print "Done.\n"