use strict;
use warnings;

# ABSTRACT: load YAML from cache or disk, whichever seems better
package YAML::CacheLoader;

use base qw( Exporter );
our @EXPORT_OK = qw( LoadFile DumpFile FlushCache );

use constant CACHE_SECONDS   => 593;                   # Relatively nice prime number just under 10 minutes.
use constant CACHE_NAMESPACE => 'YAML-CACHELOADER';    # Make clear who dirtied up the memory

use Cache::RedisDB;
use Path::Tiny;
use YAML ();

sub LoadFile {
    my ($path, $force_reload) = @_;

    my $file_loc = path($path)->canonpath;             # realpath would be more accurate, but slower.

    if (not $force_reload) {
        my $from_cache = Cache::RedisDB->get(CACHE_NAMESPACE, $file_loc);
        return $from_cache if $from_cache;             # Happy path
    }

    # Looks like we'll need to actually do some work, then.
    my $structure = YAML::LoadFile($file_loc);         # Let this fail in whatever ways it might.

    Cache::RedisDB->set(CACHE_NAMESPACE, $file_loc, $structure, CACHE_SECONDS) if ($structure);

    return $structure;
}

sub DumpFile {
    my ($path, $structure) = @_;

    my $file_loc = path($path)->canonpath;             # realpath would be more accurate, but slower.

    if ($structure) {
        YAML::DumpFile($file_loc, $structure);
        Cache::RedisDB->set(CACHE_NAMESPACE, $file_loc, $structure, CACHE_SECONDS);
    }

    return $structure;
}

sub FlushCache {

    my $redis = Cache::RedisDB->redis;
    # Here we rely on a little bit of implementation knowledge about Cache::RedisDB
    my @cache_keys = @{$redis->keys(CACHE_NAMESPACE . '*')};    # Hopefully nobody is using a longer version

    return @cache_keys ? $redis->del(@cache_keys) : 0;
}

1;
