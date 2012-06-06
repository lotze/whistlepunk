var config = {}

config.db = {};
config.redis = {};
config.msg_source_redis = {};

config.db.hostname = 'localhost';
config.db.user = 'root';
config.db.password = 'password';
config.db.database = 'metricizer';
config.redis.host = '127.0.0.1';
config.redis.port = 6379;
config.redis_db_num = 0;
config.msg_source_redis.host = '127.0.0.1';
config.msg_source_redis.port = 6379;
config.msg_source_redis.redis_db_num = 0;
config.mongo_db_name = process.env.NODE_ENV+'WhistlePunk';
config.mongo_db_server = '127.0.0.1';
config.mongo_db_port = 27017;

switch(process.env.NODE_ENV) {
case 'production':
  config.db.user = 'metricizer';
  config.db.database = 'metricizer_prod';
  config.db.password = 'PROD_PASSWORD';
  config.msg_source_redis.host = 'REDIS_HOST';
  break;
case 'test':
  config.db.database = 'metricizer_test';
  config.redis_db_num = 3;
  break;
case 'development':
  config.db.database = 'metricizer_dev';
  config.redis_db_num = 2;
  break;
default:
  console.log("No configuration!!")
}

module.exports = config;