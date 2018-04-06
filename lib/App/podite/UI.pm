package App::podite::UI;
use Mojo::Base -strict;
use Exporter 'import';
use Text::Wrap ();
use Mojo::Util 'encode', 'term_escape';
use Carp ();

our @EXPORT_OK =
  ( 'menu', 'choose_many', 'prompt', 'choose_one', 'list_things' );

sub prompt {
    my ($msg) = @_;
    print term_escape("$msg> ");
    my $k = <STDIN>;
    if ( !$k ) {
        print "\n";
        return $k;
    }
    chomp($k);
    return $k;
}

sub list_things {
    my ($things) = @_;

    my $size    = @$things;
    my $padding = length($size);
    my $fmt     = "%${padding}s. %s\n";
    my $prefix  = " " x ( $padding + 2 );

    my $idx = 1;
    for my $thing ( @{$things} ) {
        my $title = ref($thing) eq 'ARRAY' ? $thing->[0] : $thing;
        print term_escape(
            encode(
                'UTF-8', sprintf $fmt,
                $idx++, Text::Wrap::wrap( "", $prefix, $title )
            )
        );
    }
    return;
}

sub expand_list {
    my ( $list, $length ) = @_;
    my @elements = map { split(',') } split( ' ', $list );
    my @result;
    for (@elements) {
        if (/^\*$/) {
            return ( 1 .. $length );
        }
        elsif (/^(\d+)-(\d+)$/) {
            my ( $from, $to ) = ( $1, $2 );
            $to   = $length if $to > $length;
            $from = 1       if $from < 1;
            push @result, $from .. $to;
        }
        elsif (/^(\d+)-$/) {
            my $from = $1;
            $from = 1 if $from < 1;
            push @result, $1 .. $length;
        }
        elsif (/^(\d+)$/) {
            next if $1 < 1 || $1 > $length;
            push @result, $1;
        }
    }
    return @result;
}

sub choose_many {
    my ( $prompt, $things, %options ) = @_;
    $things = maybe_code($things);
    while (1) {
        if ( !$options{hide} ) {
            list_things($things);
        }
        my $k = prompt("$prompt>");

        return if !defined $k;
        return if 'quit' =~ /^\Q$k/;

        next if $k =~ /^\s+$/;
        my @list = expand_list( $k, scalar @$things );
        my @selected = @{$things}[ map { $_ - 1 } @list ];

        if (@selected) {
            return [ map { ref($_) eq 'ARRAY' && @$_ == 2 ? $_->[1] : $_ }
                  @selected ];
        }
        return;
    }
}

sub choose_one {
    my ( $prompt, $things, %options ) = @_;
    $things = maybe_code($things);
    while (1) {
        if ( !$options{hide} ) {
            list_things($things);
        }

        my $k = prompt($prompt);

        return if !defined $k;

        next if $k =~ /^\s+$/;

        my $thing;
        if ( $k =~ /^[0-9]+$/ && $k >= 0 && $k <= @$things ) {
            $thing = $things->[ $k - 1 ];
        }

        my @match = grep { $_->[0] =~ /^\Q$k/ } @$things;
        if ( @match == 1 ) {
            $thing = $match[0]->[1];
        }
        if ($thing) {
            if ( ref($thing) eq 'ARRAY' && @$thing == 2 ) {
                return $thing->[1];
            }
            return $thing;
        }
        return '';
    }
}

sub menu {
    my $menu = shift;

    $menu->{error_msg} ||= 'Huh?';

    $menu->{run_on_startup}->() if $menu->{run_on_startup};

    while (1) {

        my $prompt = maybe_code( $menu->{prompt_msg} ) || 'What now';

        my @commands =
          grep { $_->{commands} || $_->{action} }
          map { maybe_code($_) } @{ maybe_code( $menu->{commands} ) };

        say "*** Commands ***";

        my $command = choose_one( $prompt,
            [ map { [ maybe_code( $_->{title} ), $_ ] } @commands ] );

        last if !defined $command;

        if ( !$command ) {
            warn $menu->{error_msg}, "\n";
            next;
        }

        if ( $command->{commands} ) {
            menu($command);
        }
        else {
            last if !$command->{action}->();
        }
    }
    return;
}

sub maybe_code {
    return $_[0]->() if ref $_[0] eq 'CODE';
    return $_[0];
}

1;
