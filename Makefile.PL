use strict;
use warnings;
use ExtUtils::MakeMaker;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'StoreMail',
    AUTHOR              => q{GREGA POMPE <grega.pompe@informa.si>},
    VERSION_FROM        => 'lib/StoreMail.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.3118,
        'Dancer::Plugin::DBIC' => 0,
		'Template' => 0,
        'DBIx::Class::Schema::Loader' => 0,
        'Dancer::Plugin::Ajax' => 0,
        'DBI' => 0,
        'Dancer::Plugin::Email' => 0,
        'Plack::Handler::Starman' => 0,
        'Mail::IMAPClient' => 0,
		'FindBin' => 0,
		'Getopt::Long' => 0,
		'MIME::QuotedPrint::Perl' => 0,
		'MIME::Base64' => 0,
		'Email::MIME' => 0,
		'Time::ParseDate' => 0,
		'DateTime' => 0,
		'Try::Tiny' => 0, 
		'Encode' => 0,
		'File::Path' => 0,
		'Cwd' => 0,
		'Proc::Daemon' => 0,
		'File::Spec::Functions' => 0,
		'Digest::MD5' => 0,
		'DBIx::Class::Helpers' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Mail-*' },
);
