package App::podite::UI;
use Mojo::Base -base;
use Exporter 'import';

our @EXPORT_OK = ('menu','command');

has commands => sub { [] };
has prompt_msg => 'What now> ';
has error_msg => sub { say "Huh ($_[0])?"; };
has 'title';

sub menu {
	__PACKAGE__->new(@_);
}

sub command {
	App::podite::UI::Command->new(@_);
}

sub prompt {
	my ($self, $msg ) = @_;
	print ($msg || $self->prompt_msg);
	my $k = <STDIN>;
	if (!$k) {
		print "\n";
		return $k;
	}
	chomp($k);
	return $k;
}

sub match {
	my ($self, $k ) = @_;
	return if ! defined $k;
	if ( $k =~ /[0-9]+/ && $k >= 0 && $k <= @{ $self->commands } ) {
		return $self->commands->[ $k - 1 ];
	}
	my @match = grep { $_->title =~ /^\Q$k/ } @{ $self->commands };
	if ( @match == 1 ) {
		return $match[0];
	}
	return;
}

sub run {
    my $self = shift;
    while (1) {
        say "*** Commands ***";
        while ( my ( $idx, $val ) = each @{ $self->commands } ) {
            say STDOUT ($idx + 1 ) . ". " . $val->title;
        }

        my $k = $self->prompt;

	if ( ! defined $k ) {
		say "Bye.";
		exit 0;
	}

        if ( my $command = $self->match($k) ) {
	    if ( $command->isa('App::podite::UI') ) {
		    $command->run;
	    }
	    elsif ($command->isa('App::podite::UI::Command')) {
		    my @args;
		    if ( $command->args ) {
			    push @args, $self->prompt( $command->args );
		    }
		    $command->action->(@args);
	    }
	    else {
		    warn "Unknown action for " . $command->title . "\n";
	    }
        }
	elsif ( $k =~ /^\s+$/ ) {
		next;
	}
	else {
	    $self->error_msg->($k);
	}
    }
}

package App::podite::UI::Command;
use Mojo::Base -base;

has 'action';
has 'title';
has 'args';

1;
