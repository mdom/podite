#!/usr/bin/perl

use Mojo::Base -strict;
use Mojolicious::Lite;
use Mojo::UserAgent::Server;
use Test::More;
use App::podite;
use Mojo::Feed::Reader;
use Mojo::File 'tempdir', 'tempfile';

my $opml_file = tempfile;

my $podite = App::podite->new( share_dir => tempdir->make_path );

# Silence
app->log->level('fatal');

get '/feed.xml';

{
    local (*STDERR);
    open( *STDERR, '>', \my $stderr );
    $podite->add_feed('/feed.xml');
}

ok( $podite->feeds->{'/feed.xml'} );

$podite->export_opml($opml_file);

my $fr = Mojo::Feed::Reader->new;

my @subscriptions = $fr->parse_opml($opml_file);
is( $subscriptions[0]->{text},   'Example Channel' );
is( $subscriptions[0]->{xmlUrl}, '/feed.xml' );

$podite->delete_feed( $podite->feeds->{'/feed.xml'} );
ok( not exists $podite->feeds->{'/feed.xml'} );

done_testing;

__DATA__

@@ feedxml.html.ep
<?xml version="1.0"?>
<rss version="2.0">
<channel>
	<title>Example Channel</title>
	<link>http://example.com/</link>
	<description>My example channel</description>
	<item>
		<title>News for September the Second</title>
		<link>http://example.com/2002/09/01</link>
		<description>other things happened today</description>
	</item>
	<item>
		<title>News for September the First</title>
		<link>http://example.com/2002/09/02</link>
	</item>
</channel>
</rss>
