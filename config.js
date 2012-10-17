var config = require('./config.default');
var logger = require('./lib/logger');

try {
  var update_config = require('./config.local');
  config = update_config(config);
} catch(error) {
  // check and make sure this is because the file doesn't exist -- we may not need it for development/test
  if (error.message == "Cannot find module './config.local'") {
    if (process.env.NODE_ENV == 'production') {
      logger.error("ERROR: Production deploy requires a config.local.js file");
      process.exit(1);
    }
  } else {
    logger.error("ERROR: Unexpected error reading config.local.js file",error);
    process.exit(1);
  }
}

module.exports = config;