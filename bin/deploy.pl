use Dancer ':script';
use Dancer::Plugin::DBIC qw(schema resultset rset);
schema->deploy;