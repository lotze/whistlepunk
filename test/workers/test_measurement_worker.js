var vows = require('vows'),
  assert = require('assert');

var MeasurementWorker = require('../../workers/measurement_worker').MeasurementWorker;

var suite = vows.describe('measurement_worker');

suite.addBatch({
   'a measurement worker': {
     topic: new MeasurementWorker(),
     'after processing a measureMe event': {
       'returns a 1': function (measurementWorker) {
         assert.equal(measurementWorker.processLog({'eventName':'measureMe'}), 1);
       },
       'results in at least one entry in the database existing': function (measurementWorker) {
         measurementWorker.db.query().select(["amount"])
                 .from("all_measurements")
                 .where("object_id = ?", ["testActor"])
                 .and("object_type = ?", ["testActorType"])
                 .and("measure_name = ?", ["testMeasureName"])
                 .and("measure_target = ?", [""])
                 .execute(function(error, rows, columns){
                     if (error) {
                         console.log('ERROR: ' + error);
                         return;
                     }
                     assert.strictEqual(rows.length > 0, true)
                 });
       },
     },
     'claims to not process non-measureMe events': function (topic) {
       assert.equal(topic.processLog({'eventName':'notMeasureMe'}), 0);
     }
   }
});

suite.export(module);