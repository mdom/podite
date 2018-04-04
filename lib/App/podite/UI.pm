package App::podite::UI;
use Mojo::Base -strict;
use Exporter 'import';
use Carp ();

our @EXPORT_OK = ( 'menu', 'choose_many', 'prompt', 'choose_one' );

sub prompt {
    my ($msg) = @_;
    print "$msg> ";
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
    my $idx = 1;
    for my $thing ( @{$things} ) {
        my $title = ref($thing) eq 'ARRAY' ? $thing->[0] : $thing;
        say $idx++, ". $title";
    }
    return;
}

sub expand_list {
    my ( $list, $length ) = @_;
    my @elements = map { split(',') } split( ' ', $list );
    my @result;
    for (@elements) {
        /^\*$/ && do {
            return ( 1 .. $length );
        };
        /^(\d)-(\d)$/ && do {
            my ( $from, $to ) = ( $1, $2 );
            $to = $length if $to > $length;
            push @result, $from .. $to;
            next;
        };
        /^(\d)-$/ && do {
            push @result, $1 .. $length;
            next;
        };
        push @result, $_;
    }
    return @result;
}

sub choose_many {
    my ( $prompt, $things ) = @_;
    $things = maybe_code($things);
    while (1) {
        list_things($things);
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
    my ( $prompt, $things ) = @_;
    $things = maybe_code($things);
    while (1) {
        list_things($things);

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

    $menu->{error_msg} ||= sub { say "Huh ($_[0])?" };

    $menu->{run_on_startup}->() if $menu->{run_on_startup};

    while (1) {

        my $prompt = maybe_code( $menu->{prompt_msg} ) || 'What now';

        my @commands =
          grep { $_->{commands} || $_->{action} }
          map { maybe_code($_) } @{ maybe_code( $menu->{commands} ) };

        say "*** Commands ***";

        my $command = choose_one( $prompt,
            [ map { [ maybe_code( $_->{title} ), $_ ] } @commands ] );

        return if !defined $command;

        if ( !$command ) {
            $menu->{error_msg}->("");
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
