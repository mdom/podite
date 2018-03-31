package App::podite::Render;
use Mojo::Base -strict;
use Exporter 'import';

use Mojo::DOM;
use Mojo::Util 'encode';
use Text::Wrap ();

our @EXPORT_OK = ('render_item');

sub render_item {
    my ($item) = shift;
    print "\n", encode( 'UTF-8', underline( $item->title ) );
    my $summary = render_dom( Mojo::DOM->new( $item->content ) );
    if ( length($summary) > 800 ) {
        $summary = substr( $summary, 0, 800 ) . "[SNIP]\n";
    }
    print encode( 'UTF-8', $summary ) . "\n";
    return;
}

sub underline {
    my $line      = shift;
    my $underline = '=' x length($line);
    return "$line\n$underline\n\n";
}

sub render_dom {
    my $node    = shift;
    my $content = '';
    for ( $node->child_nodes->each ) {
        $content .= render_dom($_);
    }
    if ( is_tag( $node, 'h1' ) ) {
        return underline($content);
    }
    elsif ( $node->tag && $node->tag =~ /^h(\d)$/ ) {
        return ( '#' x $1 ) . " $content\n\n";
    }
    elsif ( $node->type eq 'text' ) {
        $content = $node->content;
        $content =~ s/\.\s\.\s\./.../;
        return '' if $content !~ /\S/;
        return $content;
    }
    elsif ( is_tag( $node, 'a' ) ) {
        my $href = $node->attr('href');
        if ($href) {
            return "\[$content\]\[$href\]";
        }
        return $content;
    }
    elsif ( is_tag( $node, 'location' ) ) {
        return "$content ";
    }
    elsif ( is_tag( $node, 'p' ) ) {
        return Text::Wrap::fill( '', '', $content ) . "\n\n";
    }
    elsif ( is_tag( $node, 'b' ) ) {
        return "*$content*";
    }
    return $content;
}

sub is_tag {
    my ( $node, $tag ) = @_;
    return $node->type eq 'tag' && $node->tag eq $tag;
}

1;
