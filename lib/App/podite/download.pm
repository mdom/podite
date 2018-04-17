package App::podite::download;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    $self->load_cache;
    my $downloads = $self->choose( $opts->{list} );
    return if !$downloads;
    my $q = App::podite::URLQueue->new( ua => $self->ua );
    for my $item (@$downloads) {
        my $download_url = Mojo::URL->new( $item->enclosures->[0]->url );
        my $output_filename = $self->output_filename( $item => $download_url );
        $output_filename->dirname->make_path;
        say "$download_url -> $output_filename";
        $q->add(
            $download_url => sub {
                my ( $ua, $tx, ) = @_;
                $tx->result->content->asset->move_to($output_filename);
                $self->item_state( $item => 'downloaded' );
                warn "Download $output_filename finished\n";
            }
        );
    }
    return $q->wait;
}

1;
