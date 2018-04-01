package App::podite::UI;
use Mojo::Base -strict;
use Exporter 'import';
use Carp ();

our @EXPORT_OK = ( 'menu', 'expand_list' );

sub prompt {
    my ($msg) = @_;
    print $msg;
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
    while (1) {
        list_things($things);
        my $k = prompt("$prompt>> ");

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
    while (1) {
        list_things($things);

        my $k = prompt("$prompt> ");

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

    $menu->{prompt_msg} ||= 'What now';
    $menu->{error_msg} ||= sub { say "Huh ($_[0])?" };

    my @commands =
      grep { $_->{commands} || $_->{action} }
      map { maybe_code($_) } @{ $menu->{commands} };

    if ( my $title = $menu->{run_on_startup} ) {
        for my $cmd (@commands) {
            if ( maybe_code( $cmd->{title} ) eq $title && $cmd->{action} ) {
                $cmd->{action}->();
                last;
            }
        }
    }

    while (1) {
        say "*** Commands ***";

        my $command = choose_one( $menu->{prompt_msg},
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
            my @args;
            my $title = maybe_code( $command->{title} );
            my $args  = $command->{args};
            for my $arg ( @{ $args || [] } ) {
                my $prompt = $arg->{prompt} || $title;

                if ( $arg->{is} eq 'string' ) {
                    push @args, prompt("$prompt> ");
                }
                elsif ( $arg->{is} eq 'one' ) {
                    push @args, choose_one( $prompt, to_array( $arg->{list} ) );
                }
                elsif ( $arg->{is} eq 'many' ) {
                    push @args,
                      choose_many( $prompt, to_array( $arg->{list} ) );
                }
            }
            last if !$command->{action}->( grep { defined } @args );
        }
    }
    return;
}

sub to_array {
    my ($thing) = @_;
    my $type = ref($thing);
    return $thing if $type eq 'ARRAY';
    return $thing->() if $type eq 'CODE';
    return [];
}

sub maybe_code {
    my ($thing) = @_;
    return $thing->() if ref($thing) eq 'CODE';
    return $thing;
}

1;
