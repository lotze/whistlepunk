DataProvider = require('../lib/data_provider')
UnionRep = require('../lib/union_rep')
FileProcessorHelper = require('../lib/file_processor_helper')
Redis = require('../lib/redis')
should = require('should')
assert = require('assert')

describe 'DataProvider', =>
  before (done) =>
    unionRep = new UnionRep(1)
    Redis.getClient (err, client) =>
      @fileProcessorHelper = new FileProcessorHelper unionRep, client
      @dataProvider = new DataProvider(@fileProcessorHelper)
      @actorType = 'user'
      @actorId = 'testActor'
      done()

  describe '#measure', =>
    before (done) =>
      measureName = 'testMeasureName'
      activityId = 'my_activity_id'
      timestamp = 1337540783.254368
      measureTarget = ''
      measureAmount = 1
      @fileProcessorHelper.clearDatabase =>
        @dataProvider.measure @actorType, @actorId, timestamp, measureName, activityId, measureTarget, measureAmount, =>
          done()

    it 'should result in a correct entry in the all_measurements table', (done) =>
      @fileProcessorHelper.db.query().select(["amount"])
             .from("all_measurements")
             .where("object_id = ?", [@actorId])
             .and("object_type = ?", [@actorType])
             .and("measure_name = ?", ["testMeasureName"])
             .and("measure_target = ?", [""])
             .execute (error, rows, columns) => 
                if (error)
                  console.log('ERROR: ' + error)
                  done(error)
                assert.strictEqual(rows.length > 0, true, "rows.length is not > 0")
                assert.equal(rows[0]['amount'], 1)
                done()
                
    it 'should result in entries in the timeseries table', (done) =>
      @fileProcessorHelper.db.query("select aggregation_level, amount ,timestamp,formatted_timestamp from timeseries where measure_name = 'testMeasureName' order by timestamp desc").execute (error, rows, columns) => 
        if (error)
          console.log('ERROR: ' + error)
          done(error)
        assert.strictEqual(rows.length, 4, "there are not timeseries aggregation entries for all of day, month, year, and all")
        assert.equal(rows[0]['amount'], 1)
        assert.equal(rows[0]['timestamp'], 1337497200)
        assert.equal(rows[0]['formatted_timestamp'], '2012-05-20 US/Pacific')
        assert.equal(rows[1]['amount'], 1)
        assert.equal(rows[1]['timestamp'], 1335855600)
        assert.equal(rows[1]['formatted_timestamp'], '2012-05-01 US/Pacific')
        assert.equal(rows[2]['amount'], 1)
        assert.equal(rows[2]['formatted_timestamp'], '2012-01-01 US/Pacific')
        assert.equal(rows[3]['amount'], 1)
        done()
                    

  describe '#createObject', =>
    it 'should result in a new object in the all_objects table', (done) =>
      timestamp = 0.0
      @fileProcessorHelper.clearDatabase =>
        @dataProvider.createObject @actorType, @actorId, timestamp, =>
          @fileProcessorHelper.db.query().select(["object_id"])
                 .from("all_objects")
                 .where("object_id = ?", [@actorId])
                 .and("object_type = ?", [@actorType])
                 .execute (error, rows, columns) => 
                    if (error)
                      console.log('ERROR: ' + error)
                      done(error)
                    assert.strictEqual(rows.length, 1)
                    done()