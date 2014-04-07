#!/usr/bin/env perl
# Copyright 2014 Kevin Spencer <kevin@kevinspencer.org>
#
# Permission to use, copy, modify, distribute, and sell this software and its
# documentation for any purpose is hereby granted without fee, provided that
# the above copyright notice appear in all copies and that both the
# copyright notice and this permission notice appear in supporting
# documentation.  No representations are made about the suitability of this
# software for any purpose.  It is provided "as is" without express or 
# implied warranty.
#
################################################################################

use Data::Dumper;
use JSON::XS;
use LWP::UserAgent;
use URI;
use strict;
use warnings;

our $VERSION = '0.1';

$Data::Dumper::Indent = 1;

my $user    = ''; # last.fm username
my $api_key = ''; # last.fm api key
my $api_url = 'http://ws.audioscrobbler.com/2.0/';

get_tracks_from_lastfm();

#
# contacts last.fm and retrieves all tracks played to date, dumps results in a CSV
# file for later parsing, format: artist, trackname, playcount
# 
sub get_tracks_from_lastfm {
    my $page_to_fetch = shift;

    my $uri = URI->new($api_url);
    my %params = (
        api_key => $api_key,
        method  => 'library.getTracks',
        user    => $user,
        limit   => 500,
        format  => 'json'
    );

    # library.getTracks returns results spread out over 'pages' so we'll need to specify 
    # an offset for each page we're requesting...
    $params{page} = $page_to_fetch if ($page_to_fetch);

    $uri->query_form(%params);

    my $ua = LWP::UserAgent->new();
    $ua->agent('lastfm-library.pl/' . $VERSION);
    my $response = $ua->get($uri);
    if (! $response->is_success()) {
        die "Error when communicating with $api_url: " . $response->status_line(), "\n";
    }

    my $data = decode_json($response->content());
    die "ERROR $data->{error}: $data->{message}\n" if ($data->{error});

    binmode STDOUT, ":utf8";
    for my $track (@{$data->{tracks}{track}}) {
        print "$track->{artist}{name}, $track->{name}, $track->{playcount}\n";
    }

    my $current_page = $data->{tracks}{'@attr'}{page};
    my $end_page     = $data->{tracks}{'@attr'}{totalPages};
    # if we've no more pages to request we're all done...
    return if ($current_page == $end_page);
    # otherwise, get the next page...
    $current_page++;
    get_tracks_from_lastfm($current_page);
}
