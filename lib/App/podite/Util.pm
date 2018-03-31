package App::podite::Util;
use Mojo::Base -strict;
use Exporter 'import';

our @EXPORT_OK = ('expand_filename');

sub expand_filename {
    my $file = shift;
    $file =~ s{^ ~ ([^/]*) }
              { $1
	         ? (getpwnam($1))[7]
	         : ( $ENV{HOME} || (getpwuid($<))[7] )
	       }ex;
    return $file;
}

1;
