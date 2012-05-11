var should = require('should'),
  assert = require('assert');

var FileProcessorHelper = require('./file_processor_helper');
var fileProcessorHelper = new FileProcessorHelper();

require('coffee-script')
var FirstRequest = require('../workers/first_request');

describe('a first_request worker', function() {
  describe('after processing a firstRequest event', function() {
    before(function(done) {
      var processed = 0;
      var worker = new FirstRequest(fileProcessorHelper);
      fileProcessorHelper.clearDatabase(function() {
        worker.on('done', function(e, r) {
          processed++;
          if (processed == 3) done();
        });
        fileProcessorHelper.processFile('../metricizer/spec/log/first_sessions.log');
      });
    });
    it('results in three users in all_objects', function (done) {
      fileProcessorHelper.db.query().select(["object_id"])
             .from("all_objects")
             .where("object_type = ?", ["user"])
             .execute(function(error, rows, columns){
                 if (error) {
                     console.log('ERROR: ' + error);
                     return done(error);
                 }
                 assert.equal(rows.length, 3);
                 done();
             });
    });
    it('results in three users in olap_users', function (done) {         
      fileProcessorHelper.db.query().select(["id"])
             .from("olap_users")
             .execute(function(error, rows, columns){
                 if (error) {
                     console.log('ERROR: ' + error);
                     done(error);
                 }
                 assert.equal(rows.length, 3);
                 done();
             });
             
    });
    it('results in three users created in the appropriate day/week/month', function (done) {
      fileProcessorHelper.db.query("select day, week, month from olap_users join users_created_at on olap_users.id = users_created_at.user_id")
             .execute(function(error, rows, columns){
                 if (error) {
                     console.log('ERROR: ' + error);
                     done(error);
                 }
                 assert.equal(rows.length, 3);
                 assert.equal(rows[0].day, "1970-01-01");
                 assert.equal(rows[0].week, "1969-12-29");
                 assert.equal(rows[0].month, "1970-01-01");
                 assert.equal(rows[1].day, "1970-01-01");
                 assert.equal(rows[1].week, "1969-12-29");
                 assert.equal(rows[1].month, "1970-01-01");
                 assert.equal(rows[2].day, "1970-01-01");
                 assert.equal(rows[2].week, "1969-12-29");
                 assert.equal(rows[2].month, "1970-01-01");
                 done();
             });      
    });
    it('results in one user from google, one unknown, and one from hatchery', function (done) {
      fileProcessorHelper.db.query("select source from olap_users join sources_users on olap_users.id = sources_users.user_id")
             .execute(function(error, rows, columns){
                 if (error) {
                     console.log('ERROR: ' + error);
                     done(error);
                 }
                 assert.equal(rows.length, 3);
                 assert.equal(rows[0].source, "Unknown");
                 assert.equal(rows[1].source, "hatchery.cc");
                 assert.equal(rows[2].source, "google.com");
                 done();
             });      
    });
  });
});
