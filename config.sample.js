var config = {}

config.db = {};
config.redis = {};
config.msg_source_redis = {};

config.backup = {};
config.backup.dir = '/tmp';
config.backup.redis_rdb_dir = '/usr/local/var/db/redis';
config.backup.full_log_dir = '/tmp';

config.db.hostname = 'localhost';
config.db.user = 'metricizer';
config.db.password = 'password';
config.db.database = 'metricizer';
config.redis.host = '127.0.0.1';
config.redis.port = 6379;
config.redis.db_num = 0;
config.msg_source_redis.host = '127.0.0.1';
config.msg_source_redis.port = 6379;
config.msg_source_redis.db_num = 1;
config.mongo_db_name = process.env.NODE_ENV+'WhistlePunk';
config.mongo_db_server = '127.0.0.1';
config.mongo_db_port = 27017;

switch(process.env.NODE_ENV) {
case 'production':
  config.db.user = 'metricizer';
  config.db.database = 'metricizer_prod';
  config.db.password = 'DB_PASSWORD';
  config.msg_source_redis.host = 'REDIS_HOST';
  config.backup.dir = '/mnt/whistlepunk_backup';
  config.backup.redis_rdb_dir = '/var/lib/redis/6379';
  config.backup.full_log_dir = '/opt/grockit/log';
  break;
case 'staging':
  config.db.user = 'metricizer';
  config.db.database = 'metricizer_prod';
  config.db.password = 'DB_PASSWORD';
  config.redis.db_num = 2;
  config.backup.dir = '/mnt/whistlepunk_backup';
  config.backup.redis_rdb_dir = '/var/lib/redis/6379';
  break;
case 'test':
  config.db.database = 'metricizer_test';
  config.redis.db_num = 3;
  break;
case 'development':
  config.db.database = 'metricizer_dev';
  config.redis.db_num = 2;
  break;
default:
  console.log("No configuration for the current NODE_ENV!!")
}

module.exports = config;