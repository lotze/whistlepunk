var vows = require('vows'),
  assert = require('assert');

var FirstRequest = require('../../workers/first_request').FirstRequest;
var FileProcessorHelper = require('../file_processor_helper').FileProcessorHelper;
var MeasurementWorker = require('../../workers/measurement_worker').MeasurementWorker;


var suite = vows.describe('first_request');

suite.addBatch({
   'a first_request worker': {
     topic: new MeasurementWorker,  // fix this once first request worker works as expected ;)
     'after processing a firstRequest event': {
       'returns a 1': function (worker) {
         fileProcessorHelper = new FileProcessorHelper();
         fileProcessorHelper.processFileWithWorker('../metricizer/spec/log/first_sessions.log', worker)
       },
       'results in three users': function (worker) {         
         worker.db.query().select(["object_id"])
                 .from("all_objects")
                 .where("object_id = ?", ["user"])
                 .execute(function(error, rows, columns){
                     if (error) {
                         console.log('ERROR: ' + error);
                         return;
                     }
                     assert.equal(rows.length, 3);
                 });
         worker.db.query().select(["id"])
                 .from("olap_users")
                 .execute(function(error, rows, columns){
                     if (error) {
                         console.log('ERROR: ' + error);
                         return;
                     }
                     assert.equal(rows.length, 3);
                 });
       },
       'results in one user from google, one unknown, and one from hatchery': function (worker) {
       },
     }
   }
});

suite.export(module);