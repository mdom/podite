package App::podite::UI;
use Mojo::Base -base;
use Exporter 'import';

our @EXPORT_OK = ('menu','command');

has commands => sub { [] };
has prompt_msg => 'What now? >';
has error_msg => sub { say "Huh ($_[0])?"; };

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
	my @match = grep { $_->{title} =~ /^$k/ } @{ $self->{commands} };
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
            say STDOUT ($idx + 1 ) . ". " . $val->{title};
        }

        my $k = $self->prompt;

        if ( my $command = $self->match($k) ) {
            $command->action->();
        }
        elsif ( defined $k ) {
	    $self->error_msg->($k);
        }
	else {
		say "Bye.";
		exit 0;
	}
    }
}

package App::podite::UI::Command;
use Mojo::Base -base;

has 'action';
has 'title';
has 'prompt';

1;
