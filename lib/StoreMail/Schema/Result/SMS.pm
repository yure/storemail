use utf8;
package StoreMail::Schema::Result::SMS;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("sms");

__PACKAGE__->add_columns(
  id => { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  domain => { data_type => "varchar", is_nullable => 1, size => 255 },
  frm => { data_type => "varchar", is_nullable => 0, size => 255 },
  to => { data_type => "varchar", is_nullable => 0, size => 255 },
  body => { data_type => "text", is_nullable => 1 },
  created => { data_type => "timestamp", datetime_undef_if_invalid => 1, default_value => \"current_timestamp", is_nullable => 0, },
  port => { data_type => "varchar", is_nullable => 1, size => 25 },
  send_queue => { data_type => "tinyint", is_nullable   => 1, },
  send_status => { data_type => "tinyint", is_nullable   => 1, },
  failover_send_status => { data_type => "smallint", is_nullable   => 1, },
  send_failed => { data_type => "integer", is_nullable   => 1, },
  send_timestamp => { data_type => "datetime", is_nullable   => 1, },
  direction => { data_type => "varchar", is_nullable => 0, size => 1 },
  gateway_id => { data_type => "varchar", is_nullable => 1, size => 255 },
);

__PACKAGE__->set_primary_key("id");

use Encode;


sub hash {
	my ($self) = @_;
	
	my $hash = {$self->get_columns};
	
	return $hash;
}


sub hash_lite {
	my ($self) = @_;
	return {
		from => $self->frm,
    	to => $self->to,
    	date => $self->send_timestamp ,
    	id => $self->id ,
	}
}


sub hash_normal {
	my ($self) = @_;
	return {
		from => $self->frm,
    	to => $self->to,
    	body => $self->body,
    	date => $self->send_timestamp ,
    	id => $self->id ,
	}
}


sub plain_body {
	my ($self, %args) = @_;
	my $body = $self->body;
	return '' unless $body;
	my $substiute = [
		['č', 'c'], 
		['ž', 'z'], 
		['š', 's'], 
		['đ', 'dz'], 
		['ć', 'c'], 
		['ă', 'a'],
		['î', 'i'],
		['â', 'a'],
		['ş', 's'],
		['ș', 's'],
		['ţ', 't'],			
	];
	for my $replace (@$substiute){
		# Lowercase
		my ($f, $t) = @$replace;
		$body =~ s/$f/$t/smg;
		# Uppercase
		$f = ucfirst $f;
		$t = ucfirst $t;
		$body =~ s/$f/$t/smg;
	}
	# Leave only 7-bit	
	$body =~ s/[^a-zA-Z\d\s\$¥èéùìòÇØøÅåΔ_ΦΓΛΩΠΨΣΘΞ€ÆæßÉ!"#¤%&'ÄÖÑÜ§¿äöñüà\@£\\{}[\]|\(\)~\^\*\+,-<=>:;?]//smg;
	
	# New line encode
	$body =~ s/[\n]/%0A/smg unless $args{plain_newline};
	
	return $body; 	
}


sub plain_body_one_line {
	my ($self) = @_;
	my $body = $self->plain_body;
	$body =~ s/\n//smg;
	return $body;
}


sub failed {
	my ($self) = @_;
	if($self->send_failed){
		$self->send_failed( $self->send_failed + 1 );
	} 
	else {
		$self->send_failed(1);
	}
	$self->update;
}

1;
