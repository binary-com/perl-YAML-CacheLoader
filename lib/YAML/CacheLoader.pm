use strict;
use warnings;

# ABSTRACT: load YAML from cache or disk, whichever seems better
package YAML::CacheLoader;
our $VERSION = '0.012';

use base qw( Exporter );
our @EXPORT_OK = qw( LoadFile DumpFile FlushCache FreshenCache);

use constant CACHE_SECONDS   => 593;                   # Relatively nice prime number just under 10 minutes.
use constant CACHE_NAMESPACE => 'YAML-CACHELOADER';    # Make clear who dirtied up the memory

use Cache::RedisDB 0.07;
use Path::Tiny 0.061;
use YAML ();

=head1 FUNCTIONS

=over

=item LoadFile

my $structure = LoadFile('/path/to/yml'[, $force_reload]);

Loads the structure from '/path/to/yml' into $structure, preferring the cached version if available,
otherwise reading the file and caching the result for 593 seconds (about 10 minutes).

If $force_reload is set to a true value, the file will be loaded from disk without regard
to the current cache status.

=cut

sub LoadFile {
    my ($path, $force_reload) = @_;

    my $file_loc = path($path)->canonpath;    # realpath would be more accurate, but slower.

    if (not $force_reload) {
        my $from_cache = Cache::RedisDB->get(CACHE_NAMESPACE, $file_loc);
        return $from_cache if $from_cache;    # Happy path
    }

    # Looks like we'll need to actually do some work, then.
    my $structure = YAML::LoadFile($file_loc);    # Let this fail in whatever ways it might.

    Cache::RedisDB->set(CACHE_NAMESPACE, $file_loc, $structure, CACHE_SECONDS) if ($structure);

    return $structure;
}

=item DumpFile

DumpFile('/path/to/yml', $structure);

Dump the structure from $structure into '/path/to/yml', filling the cache along the way.

=cut

sub DumpFile {
    my ($path, $structure) = @_;

    my $file_loc = path($path)->canonpath;    # realpath would be more accurate, but slower.

    if ($structure) {
        YAML::DumpFile($file_loc, $structure);
        Cache::RedisDB->set(CACHE_NAMESPACE, $file_loc, $structure, CACHE_SECONDS);
    }

    return $structure;
}

=item FlushCache

FlushCache();

Remove all currently cached YAML documents from the cache server.

=cut

sub FlushCache {
    my @cached_files = _cached_files_list();

    return (@cached_files) ? Cache::RedisDB->del(CACHE_NAMESPACE, @cached_files) : 0;
}

=item FreshenCache

FreshenCache();

Freshen currently cached files which may be out of date, either by deleting the cache (for now deleted files) or reloading from the disk (for changed ones)
Returns a stats hash-ref.

=back
=cut

sub FreshenCache {
    # A good rough cut is to see if something _might_ have changed in the meantime
    my $cutoff = time - CACHE_SECONDS;

    my @cached_files = map { path($_) } _cached_files_list();

    my $stats = {
        examined  => scalar @cached_files,
        cleared   => 0,
        freshened => 0,
    };

    foreach my $file (@cached_files) {
        if (!$file->exists) {
            $stats->{cleared}++ if (Cache::RedisDB->del(CACHE_NAMESPACE, $file->canonpath));    # Let's not cache things which don't exist.
        } elsif ((my $mtime = $file->stat->mtime) > $cutoff
            && (my $reloaded_ago = CACHE_SECONDS - Cache::RedisDB->ttl(CACHE_NAMESPACE, $file->canonpath)))
        {
            # Now see if we might have reloaded the cache in the meantime.
            my $reloaded = time - $reloaded_ago;
            $stats->{freshened}++ if ($reloaded < $mtime && LoadFile($file, 1));
        }
    }

    return $stats;
}

sub _cached_files_list {

    return @{Cache::RedisDB->keys(CACHE_NAMESPACE)};

}

1;
