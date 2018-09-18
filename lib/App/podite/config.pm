package App::podite::config;
use Mojo::Base 'App::podite';
use Mojo::Util 'tablify';

sub run {
	my ($self, $opts) = @_;
	my $config = $self->config->all;
	if ( $opts->{key} && $opts->{value} ) {
		$self->config->get_or_set( $opts->{key}, $opts->{value} );
	}
	elsif ( $opts->{key} ) {
		print tablify [[ $opts->{key}, $self->config->get_or_set( $opts->{key} ) ]];
	}
	else {
		print tablify [ map { [ $_ => $config->{$_} ] } sort keys %$config ];
	}
}

1;
