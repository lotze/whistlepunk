var winston = require('winston');
var Mail = require('winston-mail').Mail;

var logger = function logger(){
  var singletonLogger = new (winston.Logger)({
    transports: [
      new winston.transports.Console({timestamp:true})
    ]
  });
  if (process.env.NODE_ENV == 'production') {
    singletonLogger.add(Mail, {to:'devspam@grockit.com', from:'whistlepunk_logger@grockit.com', level:'error', timestamp:true});
  }
  winston.handleExceptions(singletonLogger);
  // set this to true if we want to exit on uncaught exceptions
  // singletonLogger.exitOnError = false
  
  singletonLogger.on('error', function (err) { 
    // ...what do you do when your logger has a problem?
    console.error(err); 
  });
  
  return(singletonLogger);
}

logger.instance = null;

logger.getInstance = function(){
	if(this.instance === null){
		this.instance = new logger();
	}
	return this.instance;
}

module.exports = logger.getInstance();