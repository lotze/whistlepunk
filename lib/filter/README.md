Whistlepunk Preprocessor/Filter
===============================

The files in this directory, along with the `preprocessor` binary, make up the preprocessor/filter
portion of the Whistlepunk application. The purpose of this library is to provide a mechanism with
which to ensure that events coming from Distillery are being generated from valid users (as opposed
to bots, etc).

The preprocessor chain is made up of a series of readable and writable streams, which can be
`pipe`d into each other. A short overview follows:

Dispatcher
----------

Dispatcher is a readable stream that emits `data` events for every entry in the Redis list that the
Rails app pushes into. It responds to backpressure appropriately.

Unlike Node.js `fs` streams, Dispatcher will not emit an `end` event on its own--it is designed to
read from Redis continually. Instead, it will continue to try to stream until `destroy()` is called
on it.

### Methods

  * `pause()` - Advises the stream to stop sending data; additional `data` events may still be
emitted after calling `pause`.
  * `resume()` - Resumes streaming after a `pause()`.
  * `destroy()` - Destroys the stream, disconnecting from Redis and sending the appropriate `end`
and `clsoe` events.

### Events

  * `data (json)` - Emitted for every item found on the Distillery message queue; `json` is the
event JSON from Redis.
  * `error (error)` - Emitted when there is an error on the stream. `error` is the Error object.
  * `end` - Emitted when no more `data` events will be emitted.
  * `close` - Emitted when the stream is closed.

BacklogFiller
-------------

BacklogFiller is a writable stream that places incoming events into the Redis backlog for future
processing. It sets the score of the added entry to the event's timestamp. It applies backpressure.

### Methods

  * `write(json)` - Write an event into the backlog. Returns `true` if the stream is ready for more
data, and `false` if it wishes for an upstream source to slow down calls to `write`.
  * `end(json = null)` - Safely terminates the stream after pending writes. The optional `json`
parameter allows you to `write` a final event.
  * `destroySoon()` - Terminates the stream after pending writes. The same as calling `end()` with
no arguments; this method exists to confirm to the Node.js 0.8 stream API.
  * `destroy()` - Terminates the stream without waiting on pending writes. The stream may not emit
`close` until the current Redis operation is complete.

### Events

  * `added (json)` - Emitted for each item added to Redis. `json` is the JSON inserted into the
backlog.
  * `drain` - Emitted when the stream is ready to receive addiontal data via `write()`.
  * `error (error)` - Emitted when there is an error on the stream. `error` is the Error object.
  * `close` - Emitted when the stream is closed.

BacklogProcessor
----------------

BacklogProcessor is a duplex stream. Whenever an event is written to it via `write`, it checks the
Redis backlog for any events created up to a point in time one hour before the timestamp on the
event being written. For every event found, it will check its filter to see if the user associated
with the event has been confirmed to be a "real" (non-bot) user or not. It then TODO: DOES
SOMETHING and emits a `data` event with the appropriate data.

This stream is a bit different on its `write` method in that, other than the timestamp of the
event, it does not actually care about the event being written--`write` is simply used as a trigger
to kick off a process that reads a set of old records from Redis. `write` may not trigger another
process in this way if an older bactch process is still running. Thus, the stream applies no
backpressure (as it will simply discard superfluous events).

### Methods

  * `write(json)` - Writes a JSON-encoded event, `json`, to the stream to kick off processing the
event.
  * `end(json = null)` - Safely terminates the stream after pending writes. The optional `json`
parameter allows you to `write` a final event.
  * `destroySoon()` - Terminates the stream after pending writes. The same as calling `end()` with
no arguments; this method exists to confirm to the Node.js 0.8 stream API.
  * `destroy()` - Terminates the stream without waiting on pending writes. Waits for Redis to
`quit` before emitting `close`.
  * `pause()` - Advises the stream to stop sending data; additional `data` events may still be
emitted after calling `pause`.
  * `resume()` - Resumes streaming after a `pause()`.

### Events

  * `data (json)` - Emitted once an event has been filtered by the processor. `json` is the event
JSON.
  * `end` - Emitted once no more `data` events will be emitted.
  * `doneProcessing` - Emitted once for each _set_ of events that the processor finishes processing.
  * `error (error)` - Emitted when there is an error on the stream. `error` is the Error object.
  * `close` - Emitted when the stream is closed.
