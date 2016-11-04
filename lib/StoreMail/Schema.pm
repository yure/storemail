use utf8;
package StoreMail::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_components(qw/Helper::Schema::QuoteNames/);

__PACKAGE__->load_namespaces;

our $VERSION = 39;

1;
