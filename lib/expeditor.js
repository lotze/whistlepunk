var Expeditor = function() {
  this.counter = 0;
  this.finished = {};
  this.whens = {};
  if (arguments.length == 2) this._overloaded.apply(this, arguments);
  return this.overloaded = this._overloaded.bind(this);
};

Expeditor.prototype = {
  finish: function(label, doNow) {
    var self = this;
    var fun = function() {
      self.finished[label] = true;
      self.checkWhens();
    };

    if(doNow) fun();
    return fun;
  },
  
  when: function(labels, callback) {
    this.whens[this.counter++] = {labels: labels, callback: callback};
    this.checkWhens();
  },
  
  checkWhens: function() {
    for(var i in this.whens){
      var when = this.whens[i];
      if(this.isFinished(when)){
        when.callback();
        delete(this.whens[i]);
      }
    }
  },
  
  isFinished: function(when) {
    var labels = when.labels;
    var finished = this.finished;
    return labels.every(function(label) {
      return (label in finished);
    });
  },
  
  _overloaded: function(arg1, arg2) {
    switch(typeof(arg1)) {
      case 'object':
        if(arg1 instanceof Array){
          this.when(arg1, arg2);
          return this.overloaded;
        }
        break;
      case 'string':
      case 'number':
        return this.finish(arg1, arg2);
    }
    throw new Error('what the fuck is "'+typeof(arg1)+'" doing in your risotto? oh fuck off!');
  }
};

exports.Expeditor = Expeditor;
