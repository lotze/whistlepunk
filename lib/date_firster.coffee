# make "first day of the week" and "first day of the month" dates

moment = require 'moment'

class DateFirster
  constructor: (dateOrMoment) ->
    @moment = moment(dateOrMoment)

  date: =>
    new DateFirster @moment.clone().hours(0).minutes(0).seconds(0).milliseconds(0)

  firstOfMonth: =>
    new DateFirster @moment.clone().date(1).hours(0).minutes(0).seconds(0)

  firstOfWeek: =>
    newDay = if @moment.day() >= 1 then 1 else -1
    new DateFirster @moment.clone().day(newDay).hours(0).minutes(0).seconds(0)

  firstOfYear: =>
    new DateFirster @moment.clone().month(0).date(1).hours(0).minutes(0).seconds(0)
    
  unix: =>
    @moment.unix()

  format: =>
    @moment.format("YYYY-MM-DD")
    
module.exports = DateFirster