angular.module('loomioApp').factory 'ThreadWindow', (Records, RecordLoader) ->
  class ThreadWindow
    reset: (initialSequenceId) ->
      @per = 10
      @orderBy = 'createdAt'
      @setMin(initialSequenceId || 1)
      @setMax(@minSequenceId - 1)
      @loader = new RecordLoader
        collection: 'events'
        params:
          discussion_key: @discussion.key
        per: @per
        from: @minSequenceId

    constructor: ({@discussion}) ->
      @reset()

    setMin: (val) ->
      @minSequenceId = val
      if @minSequenceId < @discussion.firstSequenceId
        @minSequenceId = @discussion.firstSequenceId

    setMax: (val) ->
      @maxSequenceId = val
      if @maxSequenceId >= @discussion.lastSequenceId
        @maxSequenceId = null # allows new events to show up

    increaseMax: =>
      @setMax(@maxSequenceId += @per)

    decreaseMin: =>
      @setMin(@minSequenceId -= @per)

    anyNext: ->
      @maxSequenceId != null

    loadNext: ->
      if @anyNext()
        @loader.loadMore(@maxSequenceId).then(@increaseMax)

    anyPrevious: ->
      @minSequenceId > @discussion.firstSequenceId

    loadPrevious: ->
      if @anyPrevious()
        @decreaseMin()
        @loader.loadPrevious(@minSequenceId)

    numPrevious: ->
      @minSequenceId - @discussion.firstSequenceId

    loadAll: ->
      @loader.per = Number.MAX_SAFE_INTEGER
      @minSequenceId = @discussion.firstSequenceId
      @maxSequenceId = null
      @loader.loadMore(@minSequenceId)

    pageOf: (event) ->
      unread = event.sequenceId > @discussion.lastReadSequenceId ? 1 : 0
      parseInt(event.sequenceId / @per) + unread

    rootsAndOrphans: (event) =>
      (!event.parentId? || event.parent().kind == "new_discussion") ||
      !@inWindow(event.parent())

    fewerDiscussionEditedEvents: (events) ->
      _.reject events, (event) =>
        event.kind == "discussion_edited" &&
        (event.pos == 0 || (event.previous() || {}).kind == "discussion_edited")

    events: =>
      query =
        sequenceId:
          $between: [@minSequenceId, (@maxSequenceId || Number.MAX_VALUE)]
        discussionId: @discussion.id

      events = Records.events.collection.find(query)
      @fewerDiscussionEditedEvents(_.filter(events, @rootsAndOrphans))

    noEvents: ->
        !_.any(@events())

    inWindow: (event) ->
      event.sequenceId >= @minSequenceId &&
      ((@maxSequenceId == null) || event.sequenceId <= @maxSequenceId)

    isFirstUnread: (event) ->
      (event.sequenceId == @discussion.lastReadSequenceId + 1) &&
      (@discussion.lastSequenceId > @discussion.lastReadSequenceId)