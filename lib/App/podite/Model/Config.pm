package App::podite::Model::Config;
use Mojo::Base 'App::podite::Model';

has table => 'config';

has default => sub {
    {
        download_dir    => "~/Podcasts",
        output_template => '<%= "$feed_title/$title.$ext" %>',
    }
};

sub all {
    shift->get_or_set;
}

sub get_or_set {
    my ( $self, $key, $value ) = @_;
    if ( $key && $value ) {
        return $self->query(
            'insert or replace into config (key, value) values ( ?, ?)',
            $key, $value );
    }
    if ($key) {
        my $result = $self->find( { key => $key } )->first;
        return $result ? $result->{value} : $self->default->{$key};
    }
    return {
        %{ $self->default },
        map { $_->{key} => $_->{value} } $self->find->each
    };
}

sub download_dir    { shift->get_or_set( download_dir    => @_ ) }
sub output_template { shift->get_or_set( output_template => @_ ) }

1;
