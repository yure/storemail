#!/usr/bin/env perl
use Dancer ':script';
use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Helper;
use DateTime::Format::Strptime;

my $domain = shift @ARGV;
my $arg = shift @ARGV;

my $message = schema->resultset('Message')->search({message_id => {'<' => 383673}, domain => {'-not' => undef}}, {columns => ['id'], order_by => 'id'});

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
	next unless $message_id_only->id > 51266;
	my $message = schema->resultset('Message')->find($message_id_only->id);
	my $format = new DateTime::Format::Strptime(pattern => "%Y-%m-%d %H:%M:%S", time_zone => $timezones->{$message->domain});
	
	my $time = $format->parse_datetime($message->date);
	$time->set_time_zone("UTC");
	my $new_date = $time->ymd() . ' ' .$time->hms();
	printt $message->date . ' - '.$new_date. ' ('.$message->id.')';
	$message->date($new_date);
	#$message->update;
}

print "\n";
