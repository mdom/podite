package App::podite::UI;
use Mojo::Base -strict;
use Exporter 'import';

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
        /^(-)?(\d)-(\d)$/ && do {
            push @result, map { $1 ? "-$_" : $_ } ( $2 .. $3 );
            next;
        };
        /^(-)?(\d)-$/ && do {
            push @result, map { $1 ? "-$_" : $_ } ( $2 .. $length );
            next;
        };
        push @result, $_;
    }
    return @result;
}

sub multiple_choice {
    my ( $prompt, $things ) = @_;
    while (1) {
        list_things($things);
        my $k = prompt("$prompt> ");

        return if !defined $k;

        next if $k =~ /^\s+$/;

        my $thing;
        if ( $k =~ /[0-9]+/ && $k >= 0 && $k <= @$things ) {
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

sub choice {
    my ( $prompt, $things ) = @_;
    while (1) {
        list_things($things);

        my $k = prompt("$prompt> ");

        return if !defined $k;

        next if $k =~ /^\s+$/;

        my $thing;
        if ( $k =~ /[0-9]+/ && $k >= 0 && $k <= @$things ) {
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
      grep { $_->{commands} || $_->{action} } @{ $menu->{commands} };

    if ( my $title = $menu->{run_on_startup} ) {
        for my $cmd (@commands) {
            if ( $cmd->{title} eq $title && $cmd->{action} ) {
                $cmd->{action}->();
                last;
            }
        }
    }

    while (1) {
        say "*** Commands ***";

        my $command = choice( $menu->{prompt_msg},
            [ map { [ $_->{title}, $_ ] } @commands ] );

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
            my $title = $command->{title};
            if ( my $args = $command->{args} ) {
                if ( ref($args) eq 'CODE' ) {
                    push @args, choice( $title, $args->() );
                }
                elsif ( ref($args) eq 'ARRAY' ) {
                    push @args, choice( $title, $args );
                }
                else {
                    push @args, prompt($args);
                }
            }
            last if !$command->{action}->(@args);
        }
    }
    return;
}

1;
