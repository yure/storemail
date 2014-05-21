### use this module to generate a set of class files

  # in a script
  use DBIx::Class::Schema::Loader qw/ make_schema_at /;
  make_schema_at(
      'Mail::Schema',
      { debug => 1,
        dump_directory => '../lib',
      },
      [ 'dbi:mysql:dbname=mail;host=localhost;port=3306', 'root', 'toor',
      ],
  );