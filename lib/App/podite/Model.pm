package App::podite::Model;
use Mojo::Base -base;

has 'sql';
has db => sub { shift->sql->db };

1;
