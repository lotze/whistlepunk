process.env.NODE_ENV = process.env.NODE_ENV || 'development';

var ENV =  {
  base: {
    logPath: 'log/',
    fun: 'always',
  },
  
  test: {
    logPath: '/tmp/'
  },
  
  development: {
    appClientHost: '127.0.0.1'
  },
  
  production: {
    appClientHost: 'learni.st'
  },
  
  ports: {
    // studyHallStream: 5555,
    // studyHallBackChannel: 5557
  },
  
  setting: function(name) {
    var env = process.env.NODE_ENV;
    var retVal = this[env] && name in this[env] ? this[env][name] : this.base[name];
    return (typeof(retVal) == 'function') ? retVal() : retVal;
  }
};

module.exports = ENV;
