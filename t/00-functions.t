#!/usr/bin/env perl
use strict;
use warnings;

use Test::Most;
use Test::RedisServer;

use Path::Tiny;

use YAML;
use YAML::CacheLoader qw( LoadFile DumpFile FlushCache FreshenCache );

my $redis_server;
eval { $redis_server = Test::RedisServer->new(conf => {port => 9966}) } or plan skip_all => 'redis-server is required to this test';

my $prev_redis = $ENV{REDIS_CACHE_SERVER};
$ENV{REDIS_CACHE_SERVER} = $redis_server->connect_info;

my $test_structure = {
    akey => 'cache-loader',
    bkey => ['testing', 'is', 'good']};

subtest 'DumpFile / LoadFile / FlushCache ' => sub {

    my $temp_file = Path::Tiny->tempfile('loaderXXXXXXX');
    my $contents  = $temp_file->slurp;
    is(length $contents, 0, $temp_file . ' starts out empty');
    DumpFile($temp_file, $test_structure);
    $contents = $temp_file->slurp;
    isnt(length $contents, 0, $temp_file . ' now contains some stuff');
    my $structure;
    lives_ok { $structure = YAML::Load($contents) } ' which loads as YAML';
    eq_or_diff($structure, $test_structure, ' and parses just as expected');
    lives_ok { $structure = LoadFile($temp_file) } $temp_file . ' loads properly via CacheLoader';
    eq_or_diff($structure, $test_structure, ' and parses just as expected');
    my $filename = $temp_file->canonpath;
    undef $temp_file;
    ok(not(-e $filename), $filename . ' no longer exists.');
    throws_ok { $structure = YAML::LoadFile($filename) } qr/Couldn't open/, ' which means YAML cannot open it';
    lives_ok { $structure = LoadFile($filename) } 'but still loads properly via CacheLoader';
    throws_ok { $structure = LoadFile($filename, 1) } qr/Couldn't open/, 'but not if we force a reload';
    is(FlushCache(), 1, 'Flushing the cache removes our single entry');
    throws_ok { $structure = LoadFile($filename) } qr/Couldn't open/, ' which means even loading via CacheLoader will not work';
    is(FlushCache(), 0, ' and flushing the cache removes no current entries.');
};

subtest 'FreshenCache' => sub {
    my $unchanged_file = Path::Tiny->tempfile('loaderXXXXXXX');
    my $deleted_file   = Path::Tiny->tempfile('loaderXXXXXXX');
    my $changed_file   = Path::Tiny->tempfile('loaderXXXXXXX');

    DumpFile($unchanged_file, $test_structure);
    $unchanged_file->touch(1);    # Very old file.

    DumpFile($deleted_file, $test_structure);
    undef $deleted_file;          # Poof!

    DumpFile($changed_file, $test_structure);
    eq_or_diff(
        FreshenCache(),
        {
            examined  => 3,
            cleared   => 1,
            freshened => 1, # We don't have the precision to know which part of the second.
        },
        'Dealt with each file change correctly.'
    );
    note "Need to update the file and sleep for a moment.";
    $changed_file->touch;
    sleep 1;
    eq_or_diff(
        FreshenCache(),
        {
            examined  => 2,    # Deleted file is gone.
            cleared   => 0,
            freshened => 1,    # Freshened the touched file.
        },
        'Second run refreshes the "changed" file.'
    );
    note "Need to just sleep for a moment.";
    sleep 1;
    eq_or_diff(
        FreshenCache(),
        {
            examined  => 2,
            cleared   => 0,
            freshened => 0,    # File is unchanged since we last looked.
        },
        'Third run does not refreshen the "changed" file.'
    );

};

$ENV{REDIS_CACHE_SERVER} = $prev_redis;
done_testing;
