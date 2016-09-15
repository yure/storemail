package StoreMail::Routes::Tag;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use StoreMail::Message;
use StoreMail::Helper;


prefix '/:domain';


get '/email_list' => sub {
	content_type('application/json');
	
	my $where->{-and} = [];
	

	# Search
	my $search =  param('search');
    push $where->{-and},[ -or => [
    	subject => { 'like', "%$search%" },
    	body => { 'like', "%$search%" },
    ]] if $search;

	# ID
	$search =  param('last_id');
    push $where->{-and}, id => { '>', param('last_id') } if $search;

	# Tag Search
	my $tags =  param('tags');
	if($tags){
		my @tags_condition;
		for my $tag (split ',', $tags){
			#push $where->{-and}, {'tags.value' => $tag};
		    push @tags_condition, 'tags.value' => $tag;
		}
	     push $where->{-and},[ -or => [
	    	@tags_condition
	    ]] if @tags_condition;
	}
    	
	# Date span
	my $from =  param('from');
	my $to =  param('to');
	#my $parser   = schema->storage->datetime_parser;
    push $where->{-and}, {date => { '<=', $to }} if $to;
    push $where->{-and}, {date => { '>=', $from }} if $from;

    	
    $where->{domain} = param('domain');
    my $messages = schema->resultset('Message')->search(
    	$where,
    	{ 
			join => ['tags'],    		 
	    		order_by => 'date',
	    		
	    		#rows => 10,
    	}
    );
    
    return to_json {
    	count => $messages->count,
    	messages =>  [map { $_->hash_lite } $messages->all],
    };    	
};



true;
