package StoreMail::Auth;
use Dancer ':syntax';
use Digest::MD5 qw(md5 md5_hex md5_base64);
use StoreMail::Helper;

sub token_today {
	my $domain = shift;
	my $day_of_year = (localtime(time()))[7];	
	my $year = (localtime(time()))[5] + 1900;
	my $salt = domain_setting($domain,'salt');	
	return md5_hex("$day_of_year$year$salt");
}


sub token_yesterday {
	my $domain = shift;
	my $day_of_year = (localtime(time()))[7];	
	$day_of_year = 0 ? 365 : $day_of_year - 1;
	my $year = (localtime(time()))[5] + 1900;
	my $salt = domain_setting($domain,'salt');	
	return md5_hex("$day_of_year$year$salt");
}


sub authenticate {
	my $domain = shift;
	return 1 if config->{'debug'};
	# Today's key
	return 1 if param('key') and param('key') eq token_today($domain);
	
	# Yesterday's key
	return 1 if param('key') and param('key') eq token_yesterday($domain);
	
	return 0;
}



# API

any '/:domain/**' => sub {
	my $req	= request;
	unless(authenticate(param('domain'))) {
		debug "Access denied for " param('domain') . ' - ' . request->{env}->{REMOTE_ADDR};
		#return 'Access denied' ;
	}
	else {
		debug "Access granted for " param('domain') . ' - ' . request->{env}->{REMOTE_ADDR};
	}
	
	content_type('application/json');
	pass;
};

true;
