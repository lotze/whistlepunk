# make "first day of the week" and "first day of the month" dates

moment = require 'moment'

class DateFirster
  constructor: (dateOrMoment) ->
    @moment = moment.utc moment(dateOrMoment)

  firstOfMonth: =>
    new DateFirster @moment.clone().date(1)

  firstOfWeek: =>
    newDay = if @moment.day() >= 1 then 1 else -1
    new DateFirster @moment.clone().day(newDay)

  format: =>
    @moment.format("YYYY-MM-DD")
    
module.exports = DateFirster