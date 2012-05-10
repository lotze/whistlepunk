var DbLoader = function () {
}

DbLoader.prototype = {
  db: function() {
    var mysql = require('db-mysql');
    db = new mysql.Database({
      hostname: 'localhost',
      user: 'root',
      password: 'password',
      database: 'metricizer_test'
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