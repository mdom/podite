package App::podite::Render;
use Mojo::Base -strict;
use Exporter 'import';

use Mojo::DOM;

our @EXPORT_OK = ('render_content');

sub render_content {
    my ($item) = shift;
    my $summary = render_dom( Mojo::DOM->new( $item->content ) );
    return $summary;
}

sub render_dom {
    my $node    = shift;
    my $content = '';
    for ( $node->child_nodes->each ) {
        $content .= render_dom($_);
    }
    if ( $node->type eq 'text' ) {
        $content = $node->content;
        $content =~ s/\.\s\.\s\./.../;
        return '' if $content !~ /\S/;
        return $content;
    }
    elsif ( $node->type eq 'tag' && $node->tag =~ /^h\d+$/
        || is_tag( $node, 'p', 'div' ) )
    {
        return "$content ";
    }
    return $content;
}

sub is_tag {
    my ( $node, @tags ) = @_;
    return
      if $node->type ne 'tag';
    for my $tag (@tags) {
        return 1
          if $node->tag eq $tag;
    }
    return;
}

1;
