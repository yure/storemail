#!/usr/bin/env perl
use Dancer ':script';
use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Helper;
use DateTime::Format::Strptime;

my $domain = shift @ARGV;
my $arg = shift @ARGV;

my $message = schema->resultset('SMS')->search({direction => 'i', domain => 'www.primerjam.si', id => {'<' => 11181}}, {columns => ['id']});

$|= 1;

my $timezones = {
	'benchmark.primerjam.si' => 'Europe/Ljubljana',
	'www.primerjam.si' => 'Europe/Ljubljana',
	'dev.primerjam.si' => 'Europe/Ljubljana',
	'dev2.primerjam.si' => 'Europe/Ljubljana',
	'sms.primerjam.si' => 'Europe/Ljubljana',
	'www.trebam.hr' => 'Europe/Zagreb',
	'dev.trebam.hr' => 'Europe/Zagreb',
	'sms.trebam.hr' => 'Europe/Zagreb',
	'www.necesit.ro' => 'Europe/Bucharest',
	'dev.necesit.ro' => 'Europe/Bucharest',
	'sms.necesit.ro' => 'Europe/Bucharest',
	'benchmark.primerjam.si' => 'Europe/Prague',
};

while (my $message_id_only = $message->next){
	my $message = schema->resultset('SMS')->find($message_id_only->id);
	next unless $message->send_timestamp;
	my $timezone = $timezones->{$message->domain} || config->{timezone};
	my $format = new DateTime::Format::Strptime(pattern => "%Y-%m-%d %H:%M:%S", time_zone => $timezone);
	
	my $time = $format->parse_datetime($message->send_timestamp);
	$time->set_time_zone("UTC");
	my $new_date = $time->ymd() . ' ' .$time->hms();
	my $old_date = $message->send_timestamp();
	my $id = $message->id;
	printt "$old_date - $new_date ($id)";
	$message->send_timestamp($new_date);
	#$message->update;
}

print "\n";