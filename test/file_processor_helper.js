var FileProcessorHelper = function () {
  this.jsonFinderRegEx = new RegExp(/^[^\{]*(\{.*\})/);
}

FileProcessorHelper.prototype = {
  processFileWithWorker: function(file, worker) {
    var lazy = require("lazy"),
    fs = require("fs");

    new lazy(fs.createReadStream(file))
      .lines
      .forEach(function(line){
        // doesn't work??
        //var matches = line.toString().match(this.jsonFinderRegEx);
        var matches = line.toString().match(/^[^\{]*(\{.*\})/);
        var jsonString = matches[1]
        var json = JSON.parse(jsonString);
        worker.processLog(json);
       }
     );
  }
}

exports.FileProcessorHelper = FileProcessorHelper