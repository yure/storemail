package StoreMail::Routes::GUI;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Helper;;
use HTML::Entities;
use DBI;

our $VERSION = '0.1';

prefix '/:domain';

get '/gui/conversation/all' => sub {
	content_type('text/html');
    return template 'all.html', {domain => param('domain')};
};


get '/gui/conversation/:id' => sub {
	content_type('text/html');
    return template 'conversation.html', {domain => param('domain'), id => param('id')};
};

get '/gui/provider/:comma_separated_emails' => sub {
	content_type('text/html');
	my @emails = map { s/\s*(\S+)\s*/$1/; $_ } split ',', param('comma_separated_emails');
	#return to_dumper \@emails;
    return template 'provider.html', {title=> 'Provider', domain => param('domain'), from => param('comma_separated_emails')};
};

get '/gui/send-batch' => sub {
	content_type('text/html');
	my $emails = domain_setting(param('domain'), 'from_emails');
	my @clean_emails;
	push @clean_emails, encode_entities($_) for @$emails;

    return template 'batch_send.html', {
    	title=> 'Batch send', 
    	domain => param('domain'),
    	from_emails => \@clean_emails,
    };
};

get '/gui/campaign' => sub {
	content_type('text/html');
	my $campaigns = schema->resultset('Batch')->search({domain => param('domain')}, {group_by => 'name'});

    return template 'campaign_list.html', {
    	title=> 'Campaign manager', 
    	domain => param('domain'),
    	campaigns => [$campaigns->all],
    };
};

get '/gui/campaign/:name' => sub {
	content_type('text/html');
	my $campaign = schema->resultset('Batch')->search({domain => param('domain'), name => param('name')})->first;

	return 'Campaign not found!' unless $campaign;

    my ($clicked, $opened, $not_opened) = $campaign->campaign_groupped_messages;

    return template 'campaign.html', {
    	title=> 'Campaign manager', 
    	domain => param('domain'),
    	clicked => $clicked,
    	opened => $opened,
    	not_opened => $not_opened,
    	campaign => $campaign,
    };
};


true;
