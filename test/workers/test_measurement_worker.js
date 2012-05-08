var vows = require('vows'),
  assert = require('assert');

var MeasurementWorker = require('../../workers/measurement_worker').MeasurementWorker;

var suite = vows.describe('measurement_worker');

suite.addBatch({
   'a measurement worker': {
     topic: new MeasurementWorker(),
     'after processing a measureMe event': {
       'returns a 1': function (worker) {
          //measurementWorker.db.query("delete from all_measurements").execute();
          assert.equal(worker.processLog({'eventName':'measureMe', 'actorId':'testActor', 'actorType':'testActorType', 'measureName':'testMeasureName', 'timestamp':0.0}), 1);
       },
       'results in at least one entry in the database existing': function (worker) {
         worker.db.query().select(["amount"])
                 .from("all_measurements")
                 .where("object_id = ?", ["testActor"])
                 .and("object_type = ?", ["testActorType"])
                 .and("measure_name = ?", ["testMeasureName"])
                 .and("measure_target = ?", [""])
                 .execute(function(error, rows, columns){
                    if (error) {
                      console.log('ERROR: ' + error);
                    }
                    console.log(rows[0]['amount']);
                    assert.strictEqual(rows.length > 0, true);
                    assert.equal(rows[0]['amount'], 1);
                 });
       },
     }
   }
});

suite.export(module);