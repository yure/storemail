#!/usr/bin/env perl
use Dancer ':script';
use StoreMail::Helper;
use DBIx::Class::DeploymentHandler;

my $dh = DBIx::Class::DeploymentHandler->new({ schema => schema, databases => 'MySQL', });
 
$dh->prepare_version_storage_install;
$dh->install_version_storage;
$dh->add_database_version({ version => schema->schema_version });

