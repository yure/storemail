package StoreMail::Helper;
use Dancer ':syntax';

use Exporter; # gives you Exporter's import() method directly
our @ISA = qw(Exporter);
our @EXPORT = qw(domain_setting trim); # symbols to export on request

sub trim {	
	my $str = shift; $str =~ s/^\s+|\s+$//g if $str; return $str;
}


sub domain_setting {
	my ($domain, $var) = @_;
	return config->{domains}->{$domain}->{$var} if defined config->{domains} and defined config->{domains}->{$domain} and defined config->{domains}->{$domain}->{$var};
	return config->{$var};
}


true;