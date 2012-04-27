// log levels: debug, info, warn, fatal
var StreamLogger = require('streamlogger').StreamLogger;
module.exports = new StreamLogger("../log/whistle_punk.log");