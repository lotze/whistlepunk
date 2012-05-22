var DbLoader = function () {
}

var config = require('../config');

DbLoader.prototype = {
  db: function() {
    var mysql = require('db-mysql');
    var db = new mysql.Database({
      hostname: config.db.hostname,
      user: config.db.user,
      password: config.db.password,
      database: config.db.database
    });
    db.on('error', function(error) {
      console.log('ERROR: ' + error);
    }).on('ready', function(server) {
      // console.log('Connected to ' + server.hostname + ' (' + server.version + ')');
    }).connect({async: false});
    return(db);
  }
}

module.exports = DbLoader;