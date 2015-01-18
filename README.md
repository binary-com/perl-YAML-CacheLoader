[![Build Status](https://travis-ci.org/binary-com/perl-YAML-CacheLoader.svg?branch=master)](https://travis-ci.org/binary-com/perl-YAML-CacheLoader)
[![Coverage Status](https://coveralls.io/repos/binary-com/perl-YAML-CacheLoader/badge.png?branch=master)](https://coveralls.io/r/binary-com/perl-YAML-CacheLoader?branch=master)
[![Gitter chat](https://badges.gitter.im/binary-com/perl-YAML-CacheLoader.png)](https://gitter.im/binary-com/perl-YAML-CacheLoader)

# FUNCTIONS

- LoadFile

    my $structure = LoadFile('/path/to/yml'\[, $force\_reload\]);

    Loads the structure from '/path/to/yml' into $structure, preferring the cached version if available,
    otherwise reading the file and caching the result for 593 seconds (about 10 minutes).

    If $force\_reload is set to a true value, the file will be loaded from disk without regard
    to the current cache status.

- DumpFile

    DumpFile('/path/to/yml', $structure);

    Dump the structure from $structure into '/path/to/yml', filling the cache along the way.

- FlushCache

    FlushCache();

    Remove all currently cached YAML documents from the cache server.

- FreshenCache

    FreshenCache();

    Freshen currently cached files which may be out of date, either by deleting the cache (for now deleted files) or reloading from the disk (for changed ones)
    Returns a stats hash-ref.
