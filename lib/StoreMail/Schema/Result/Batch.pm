use utf8;
package StoreMail::Schema::Result::Batch;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("batch");


__PACKAGE__->add_columns(
  "id" => { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "domain" => { data_type => "varchar", is_nullable => 1, size => 90 },
  "name" => { data_type => "varchar", is_nullable => 1, size => 255 },  
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(
  "messages",
  "StoreMail::Schema::Result::Message",
  { "foreign.batch_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


sub date {
	my ($self) = @_;
	my $msg = $self->messages->first;
	return undef unless $msg;
	return $msg->date;
}

sub hash {
	my ($self) = @_;
	return {
		id => $self->id,
		domain => $self->domain,
		name => $self->name,
	}
}

sub sibling_ids {
	my ($self) = @_;
	my $schema = $self->result_source->schema; 

	my $siblings = $schema->resultset('Batch')->search({name => $self->name, domain => $self->domain});

	return map {$_->id} $siblings->all; 
	
}

sub campaign_messages {
	my ($self) = @_;
	my $schema = $self->result_source->schema; 
	my @siblings = $self->sibling_ids;
	return $schema->resultset('Message')->search({ batch_id => {'-in' => \@siblings} });
}


sub campaign_groupped_messages {
	my ($self) = @_;
	
	my (@clicked, @opened, @not_opened);
    
    for my $message ($self->campaign_messages->search()->all){
    	if($message->clicks->count){
    		push @clicked, $message->hash_campaign;
    	}
    	elsif($message->opened){
    		push @opened, $message->hash_campaign;
    	}
    	else{
    		push @not_opened, $message->hash_campaign;
    	}
    }
    
    return (\@clicked, \@opened, \@not_opened);
}



1;
