var config = {}

config.db = {};
config.redis = {};
config.zmq = {};

config.db.hostname = 'localhost';
config.db.user = 'root';
config.db.password = 'password';
config.db.database = 'metricizer';
config.redis.host = '127.0.0.1';
config.redis.port = 6379;
config.zmq.host = '127.0.0.1';
config.zmq.port = 9000;

switch(process.env.WHISTLEPUNK_ENV) {
case 'production':
  config.db.database = 'metricizer_prod';
  config.db.password = 'PROD_PASSWORD';
  config.zmq.host = 'ZMQ_HOST';
  break;
case 'test':
  config.db.database = 'metricizer_test';
  break;
case 'development':
  config.db.database = 'metricizer_dev';
  break;
default:
  console.log("No configuration!!")
}

module.exports = config;