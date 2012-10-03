var config = require('./config.default');

try {
  var update_config = require('./config.local');
  config = update_config(config);
} catch(error) {
  // check and make sure this is because the file doesn't exist -- we may not need it for development/test
  if (error.message == "Cannot find module './config.local'") {
    if (process.env.NODE_ENV == 'production') {
      console.error("ERROR: Production deploy requires a config.local.js file");
      process.exit(0);
    }
  } else {
    console.error("ERROR: Unexpected error reading config.local.js file");
    process.exit(0);
  }
}

module.exports = config;