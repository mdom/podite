package App::podite::Util;
use Mojo::Base -strict;
use Exporter 'import';
use Mojo::File ();

our @EXPORT_OK = ( 'expand_filename', 'path' );

sub expand_filename {
    my $file = shift;
    $file =~ s{^ ~ ([^/]*) }
              { $1
	         ? (getpwnam($1))[7]
	         : ( $ENV{HOME} || (getpwuid($<))[7] )
	       }ex;
    return $file;
}

sub path {
    Mojo::File::path( expand_filename(shift) );
}

1;
