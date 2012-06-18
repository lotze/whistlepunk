DateFirster = require('../lib/date_firster')
should = require('should')
assert = require('assert')

describe 'DateFirster', =>
  before =>
    @timestamp = 1337540783.254368
    @dateFirster = new DateFirster(new Date(1000*@timestamp))

  describe '#format', =>
    it 'should return the appropriate date in US/Pacific, formatted YYYY-MM-DD', =>
      @dateFirster.format().should.equal '2012-05-20'

  describe '#firstOfWeek', =>
    describe "when provided a Tuesday date", =>
      it 'should return the first of the week in US/Pacific, formatted YYYY-MM-DD', =>
        dateFirster = new DateFirster(new Date('2012-05-15 12:00:00 -0700'))
        dateFirster.firstOfWeek().format().should.equal '2012-05-14'
    describe "when provided a Friday date", =>
      it 'should return the first of the week in US/Pacific, formatted YYYY-MM-DD', =>
        dateFirster = new DateFirster(new Date('2012-05-18 12:00:00 -0700'))
        dateFirster.firstOfWeek().format().should.equal '2012-05-14'
    describe "when provided a Sunday date", =>
      it 'should return the first of the week in US/Pacific, formatted YYYY-MM-DD', =>
        dateFirster = new DateFirster(new Date('2012-05-20 12:00:00 -0700'))
        dateFirster.firstOfWeek().format().should.equal '2012-05-14'


  describe '#firstOfMonth', =>
    it 'should return the first of the month in US/Pacific, formatted YYYY-MM-DD', =>
      @dateFirster.firstOfMonth().format().should.equal '2012-05-01'

  describe '#firstOfYear', =>
    it 'should return the first of the year in US/Pacific, formatted YYYY-MM-DD', =>
      @dateFirster.firstOfYear().format().should.equal '2012-01-01'
