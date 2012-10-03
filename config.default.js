var config = {};

config.db = {};
config.redis = {};
config.filtered_redis = {};
config.unfiltered_redis = {};

config.logfile = {};
config.logfile.valid_user_events = 'log/valid_user_events.log';
config.logfile.invalid_user_events = 'log/invalid_user_events.log';

config.expirations = {};
config.expirations.backlogProcessDelay = 60 * 60;
config.expirations.filterBackwardExpireDelay = 60 * 60 * 24;

config.backup = {};
config.backup.dir = '/tmp';
config.backup.redis_rdb_dir = '/usr/local/var/db/redis';
config.backup.full_log_dir = '/tmp';

config.db.hostname = 'localhost';
config.db.user = 'metricizer';
config.db.password = 'password';
config.db.database = 'metricizer';
config.mongo_db_name = process.env.NODE_ENV+'WhistlePunk';
config.mongo_db_server = '127.0.0.1';
config.mongo_db_port = 27017;

// incoming (distillery) redis queue
config.unfiltered_redis.host = '127.0.0.1';
config.unfiltered_redis.port = 6379;
config.unfiltered_redis.db_num = 1;
// 'outgoing' (filtered) redis queue
config.filtered_redis.host = '127.0.0.1';
config.filtered_redis.port = 6379;
config.filtered_redis.db_num = 2;
// internal redis (internal storage and metricizer output)
config.redis.host = '127.0.0.1';
config.redis.port = 6379;
config.redis.db_num = 2;

switch(process.env.NODE_ENV) {
case 'production':
  config.db.user = 'metricizer';
  config.db.database = 'metricizer_prod';
  config.backup.dir = '/mnt/whistlepunk_backup';
  config.backup.redis_rdb_dir = '/var/lib/redis/6379';
  config.backup.full_log_dir = '/opt/grockit/log';
  break;
case 'staging':
  config.db.hostname = 'staging-mysql-master';
  config.db.user = 'learnist';
  config.db.database = 'metricizer_prod';
  config.backup.dir = '/mnt/whistlepunk_backup';
  config.backup.redis_rdb_dir = '/var/lib/redis/6379';
  config.backup.full_log_dir = '/opt/grockit/log';
  config.unfiltered_redis.host = 'staging-redis-master';
  config.redis.host = 'staging-redis-master';
  config.redis.db_num = 2;
  config.filtered_redis.host = 'staging-redis-master';
  config.filtered_redis.db_num = 2;
  break;
case 'test':
  config.db.database = 'metricizer_test';
  config.unfiltered_redis.db_num = 3;
  config.filtered_redis.db_num = 3;
  config.redis.db_num = 3;
  break;
case 'development':
  config.db.database = 'metricizer_dev';
  config.filtered_redis.db_num = 4;
  config.redis.db_num = 4;
  break;
default:
  console.log("No configuration for the current NODE_ENV!!")
}

module.exports = config;
