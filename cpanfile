requires 'Cache::RedisDB', '0.07';
requires 'Path::Tiny', '0.061';
requires 'YAML';

on test => sub {
    requires 'Test::Most', '0.34';
    requires 'File::Temp', '0.23';
    recommends 'Test::RedisServer', '0.14';
};
