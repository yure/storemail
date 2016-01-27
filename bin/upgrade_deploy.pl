#!/usr/bin/env perl
use Dancer ':script';
use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBIx::Class::DeploymentHandler;

my $dh = DBIx::Class::DeploymentHandler->new({ schema => schema, databases => 'MySQL', });
 

#$dh->prepare_deploy;
#$dh->prepare_upgrade({ from_version => 1, to_version => 2});
$dh->upgrade;