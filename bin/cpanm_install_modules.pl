#!/usr/bin/perl 

use strict;
use warnings;
use CPAN;
use CPAN::FindDependencies;
use File::Basename;

my $mod = shift @ARGV;

for $mod (CPAN::Shell->expand("Module", $mod )) {
        print $mod->cpan_file, "\n";
}

my @dependencies = CPAN::FindDependencies::finddeps($mod,);
        foreach my $dep (@dependencies) {
        print ' ' x $dep->depth();
        print  $dep->name().' ('.$dep->distribution().")\n";
}
