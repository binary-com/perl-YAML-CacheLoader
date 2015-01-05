use strict;
use warnings;

# ABSTRACT: load YAML from cache or disk, whichever seems better
package YAML::CacheLoader;

use base qw( Exporter );
our @EXPORT_OK = qw( LoadFile );

use constant CACHE_SECONDS   => 593;                   # Relatively nice prime number just under 10 minutes.
use constant CACHE_NAMESPACE => 'YAML-CACHELOADER';    # Make clear who dirtied up the memory

use Cache::RedisDB;
use Path::Tiny;
use Sereal qw( encode_sereal decode_sereal looks_like_sereal );
use YAML qw( LoadFile );

sub LoadFile {
    my ($path, $force_reload) = @_;

    my $file_loc = path($path)->canonpath;             # realpath would be more accurate, but slower.

    my $from_cache = Cache::RedisDB->get(CACHE_NAMESPACE, $file_loc);
    return decode_sereal($from_cache) if ($from_cache and looks_like_sereal($from_cache));    # Happy path

    # Looks like we'll need to actually do some work, then.
    my $structure = LoadFile($file_loc);                                                      # Let this fail in whatever ways it might.

    Cache::RedisDB->set(CACHE_NAMESPACE, encode_sereal($structure), CACHE_SECONDS) if ($structure);

    return $structure;
}

1;
