var config = {}

config.db = {};
config.redis = {};
config.filtered_redis = {};
config.unfiltered_redis = {};

config.backup = {};
config.backup.dir = '/tmp';
config.backup.redis_rdb_dir = '/usr/local/var/db/redis';
config.backup.full_log_dir = '/tmp';

config.db.hostname = 'localhost';
config.db.user = 'root';
config.db.password = 'password';
config.db.database = 'metricizer';
config.redis.host = '127.0.0.1';
config.redis.port = 6379;
config.redis.db_num = 0;
config.filtered_redis.host = '127.0.0.1';
config.filtered_redis.port = 6379;
config.filtered_redis.db_num = 0;
config.unfiltered_redis.host = '127.0.0.1';
config.unfiltered_redis.port = 6379;
config.unfiltered_redis.db_num = 4;
config.mongo_db_name = process.env.NODE_ENV+'WhistlePunk';
config.mongo_db_server = '127.0.0.1';
config.mongo_db_port = 27017;

switch(process.env.NODE_ENV) {
case 'production':
  config.db.user = 'metricizer';
  config.db.database = 'metricizer_prod';
  config.db.password = 'PROD_PASSWORD';
  config.unfiltered_redis.host = 'REDIS_HOST';
  config.backup.dir = '/mnt/whistlepunk_backup';
  config.backup.redis_rdb_dir = '/var/lib/redis/6379';
  break;
case 'test':
  config.db.database = 'metricizer_test';
  config.redis.db_num = 3;
  config.filtered_redis.db_num = 3;
  break;
case 'development':
  config.db.database = 'metricizer_dev';
  config.redis.db_num = 2;
  config.filtered_redis.db_num = 2;
  break;
default:
  console.log("No configuration!!")
}

module.exports = config;