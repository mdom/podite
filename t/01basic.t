use Mojo::Base -strict;
use Test::More;
use Mojo::File 'path';
use Mojo::URL;
use FindBin qw($Bin);
use Mojo::Feed;
use App::podite;

my $reader = Mojo::Feed::Reader->new;
my $feed   = $reader->parse("$Bin/samples/rss20-enclosure.xml");
ok($feed);

my $app = App::podite->new( state_file => Mojo::File->tempfile('poditeXXXXX') );

my $item = $feed->items->first;

my $url = Mojo::URL->new( $item->enclosures->first->url );

is( $app->output_filename( $item, $url ),
    "$ENV{HOME}/Podcasts/enclosure-demo/attachmentenclosure-example.mp3"
);

done_testing;
