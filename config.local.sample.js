function update_config(config) {
  switch(process.env.NODE_ENV) {
  case 'production':
    config.db.password = 'PROD_METRICIZER_DB_PASSWORD';
    config.unfiltered_redis.host = 'PROD_DISTILLERY_REDIS_HOST';
    break;
  case 'staging':
    config.db.password = 'STAGING_METRICIZER_DB_PASSWORD';
    break;
  case 'test':
    break;
  case 'development':
    break;
  default:
    console.log("No configuration for the current NODE_ENV!!")
  }
  return(config);
}

module.exports = update_config;
