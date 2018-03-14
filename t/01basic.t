use Mojo::Base -strict;
use Test::More;
use Mojo::File 'path';
use Mojo::URL;
use FindBin qw($Bin);
use Mojolicious::Plugin::FeedReader;
use App::podite;

my $reader = Mojolicious::Plugin::FeedReader->new;
my $feed   = $reader->parse_rss("$Bin/samples/rss20-enclosure.xml");
ok($feed);

my $app = App::podite->new( state_file => Mojo::File->tempfile('poditeXXXXX') );

my $item = $feed->{items}->[0];
$item->{feed_name} = 'foo';
$app->config->{feeds}->{foo}->{download_dir} = path("/home/bar/Podcasts");

my $url = Mojo::URL->new( $item->{enclosures}->[0]->{url} );

is(
    $app->output_filename( $item, $url ),
    '/home/bar/Podcasts/foo/sample_podcast.mp3'
);
$app->config->{feeds}->{foo}->{output_filename} =
  '<%= $feed_name %>/<%== $title %>.<%= $ext %>';
is( $app->output_filename( $item, $url ),
    '/home/bar/Podcasts/foo/attachmentenclosure-example.mp3' );

done_testing;
