// var should = require('should'),
//   assert = require('assert');
// 
// var MeasurementWorker = require('../workers/measurement_worker.js');
// var FileProcessorHelper = require('./file_processor_helper.js');
// var fileProcessorHelper = new FileProcessorHelper();
// 
// describe('a measurement worker', function() {
//   beforeEach(function(done){
//     fileProcessorHelper.clearDatabase(function(err){
//       if (err) return done(err);
//       done();
//     });
//   })
//   describe('after processing a measureMe event', function() {
//     it('should result in at a correct entry in the database', function (done) {
//       var worker = new MeasurementWorker(fileProcessorHelper);
//       worker.processEvent({'eventName':'measureMe', 'actorId':'testActor', 'actorType':'testActorType', 'measureName':'testMeasureName', 'timestamp':0.0});
//       fileProcessorHelper.db.query().select(["amount"])
//              .from("all_measurements")
//              .where("object_id = ?", ["testActor"])
//              .and("object_type = ?", ["testActorType"])
//              .and("measure_name = ?", ["testMeasureName"])
//              .and("measure_target = ?", [""])
//              .execute(function(error, rows, columns){
//                 if (error) {
//                   console.log('ERROR: ' + error);
//                   // done(error);
//                 }
//                 assert.strictEqual(rows.length > 0, true);
//                 assert.equal(rows[0]['amount'], 1);
//                 done();
//              });
//     })
//   })
// });
