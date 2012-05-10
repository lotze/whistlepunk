var should = require('should'),
  assert = require('assert');

var FileProcessorHelper = require('./file_processor_helper.js');
var fileProcessorHelper = new FileProcessorHelper();

var FirstRequest = require('../workers/first_request');

describe('a first_request worker', function() {
  describe('after processing a firstRequest event', function() {
    before(function() {
      var worker = new FirstRequest(fileProcessorHelper);
      fileProcessorHelper.clearDatabase();
      fileProcessorHelper.processFile('../metricizer/spec/log/first_sessions.log');
    }),
    it('results in three users in all_objects', function (done) {
      fileProcessorHelper.db.query().select(["object_id"])
             .from("all_objects")
             .where("object_id = ?", ["user"])
             .execute(function(error, rows, columns){
                 if (error) {
                     console.log('ERROR: ' + error);
                     return;
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
                     return;
                 }
                 assert.equal(rows.length, 3);
                 done();
             });
    });
    it('results in one user from google, one unknown, and one from hatchery', function (done) {
      fileProcessorHelper.db.query("select source from olap_users join sources_users on olap_users.id = sources_users.user_id")
             .execute(function(error, rows, columns){
                 if (error) {
                     console.log('ERROR: ' + error);
                     return;
                 }
                 assert.equal(rows.length, 3);
                 console.log(rows);
                 assert.equal(rows[0], "google.com");
                 assert.equal(rows[1], "hatchery.cc");
                 assert.equal(rows[2], "Unknown");
                 done();
             });      
    });
  });
});
