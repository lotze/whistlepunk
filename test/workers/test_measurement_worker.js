var vows = require('vows'),
    assert = require('assert');

var MeasurementWorker = require('../../workers/measurement_worker').MeasurementWorker;

var suite = vows.describe('measurement_worker');

suite.addBatch({
   'a measurement worker': {
       topic: new MeasurementWorker(),
       'claims to process measureMe events': function (topic) {
           assert.equal(topic.processLog({'eventName':'measureMe'}), 1);
       },
       'claims to not process non-measureMe events': function (topic) {
           assert.equal(topic.processLog({'eventName':'notMeasureMe'}), 0);
       }
   }
});

suite.export(module);