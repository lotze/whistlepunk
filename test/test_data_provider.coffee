DataProvider = require('../lib/data_provider')
FileProcessorHelper = require('./file_processor_helper')
should = require('should')
assert = require('assert')

describe 'DataProvider', =>
  before =>
    @dataProvider = new DataProvider()
    @fileProcessorHelper = new FileProcessorHelper()

  describe '#measure', =>
    it 'should result in a correct entry in the all_measurements table', (done) =>
      actorType = 'testActorType'
      actorId = 'testActor'
      measureName = 'testMeasureName'
      timestamp = 0.0
      measureTarget = ''
      measureAmount = 1
      @fileProcessorHelper.clearDatabase =>
        @dataProvider.measure actorType, actorId, timestamp, measureName, measureTarget, measureAmount, =>
          @fileProcessorHelper.db.query().select(["amount"])
                 .from("all_measurements")
                 .where("object_id = ?", ["testActor"])
                 .and("object_type = ?", ["testActorType"])
                 .and("measure_name = ?", ["testMeasureName"])
                 .and("measure_target = ?", [""])
                 .execute (error, rows, columns) => 
                    if (error)
                      console.log('ERROR: ' + error)
                      done(error)
                    assert.strictEqual(rows.length > 0, true, "rows.length is not > 0")
                    assert.equal(rows[0]['amount'], 1)
                    done()

  describe '#createObject', =>
    it 'should result in a new object in the all_objects table', (done) =>
      actorType = 'testActorType'
      actorId = 'testActor'
      timestamp = 0.0
      @fileProcessorHelper.clearDatabase =>
        @dataProvider.createObject actorType, actorId, timestamp, =>
          @fileProcessorHelper.db.query().select(["object_id"])
                 .from("all_objects")
                 .where("object_id = ?", ["testActor"])
                 .and("object_type = ?", ["testActorType"])
                 .execute (error, rows, columns) => 
                    if (error)
                      console.log('ERROR: ' + error)
                      done(error)
                    assert.strictEqual(rows.length, 1)
                    done()