define [
  'i18n!calendar'
  'jst/calendar/undatedEvents'
  'compiled/calendar/EventDataSource'
  'compiled/calendar/ShowEventDetailsDialog'
  'jqueryui/draggable'
  'jquery.disableWhileLoading'
  'vendor/jquery.ba-tinypubsub'
], (I18n, undatedEventsTemplate, EventDataSource, ShowEventDetailsDialog) ->

  class UndatedEventsList
    constructor: (selector, @dataSource, @calendar) ->
      @div = $(selector).html undatedEventsTemplate({ unloaded: true })
      @hidden = true
      @visibleContextList = []

      $.subscribe
        "CommonEvent/eventDeleting" : @eventSaving
        "CommonEvent/eventDeleted" : @eventSaved
        "CommonEvent/eventSaving" : @eventSaving
        "CommonEvent/eventSaved" : @eventSaved
        "Calendar/visibleContextListChanged" : @visibleContextListChanged

      @div.on('click', '.event', @clickEvent)
          .on('click', '.undated_event_title', @clickEvent)
          .on('click', '.undated-events-link', @show)
      @div.on('keydown', '.event', @keyDownEvent)
      if toggler = @div.prev('.element_toggler')
        toggler.on('click', @show)
        @div.find('.undated-events-link').hide()

      @showAgenda = !!ENV.CALENDAR.SHOW_AGENDA

    load: =>
      return if @hidden

      loadingDfd = new $.Deferred()
      @div.disableWhileLoading(loadingDfd, {
        buttons: ['.undated-events-link'],
        opacity: 1,
        lines: 8, length: 2, width: 2, radius: 3
      })
      $.screenReaderFlashMessage(I18n.t('loading_undated_events', 'Loading undated events'))

      @dataSource.getEvents null, null, @visibleContextList, (events) =>
        loadingDfd.resolve()
        for e in events
          e.details_url = e.fullDetailsURL()
          e.icon = if e.calendarEvent then 'calendar-day' else 'assignment'
          if @showAgenda
            e.icon = if e.calendarEvent then 'calendar-month' else e.assignmentType()
        @div.html undatedEventsTemplate({ events: events, showAgenda: @showAgenda })

        for e in events
          @div.find(".#{e.id}").data 'calendarEvent', e

        @div.find('.event').draggable
          revert: 'invalid'
          revertDuration: 0
          helper: 'clone'
          start: =>
            @calendar.closeEventPopups()
            $(this).hide()
          stop: (e, ui) ->
            # Only show the element after the drag stops if it doesn't have a start date now
            # (meaning it wasn't dropped on the calendar)
            $(this).show() unless $(this).data('calendarEvent').start
        @div.find('.undated_event:first').attr('tabindex', -1).focus()

    show: (event) =>
      event.preventDefault()
      @hidden = false
      @load()

    clickEvent: (jsEvent) =>
      jsEvent.preventDefault()
      eventId = $(jsEvent.target).data('event-id')
      # Support handling a contained element being clicked within an event
      eventId ||= $(jsEvent.target).closest('.event').data('event-id')
      event = @dataSource.eventWithId(eventId)
      if event
        new ShowEventDetailsDialog(event, @dataSource).show jsEvent

    keyDownEvent: (jsEvent) =>
      return if jsEvent.keyCode != 13 && jsEvent.keyCode != 32
      @clickEvent(jsEvent)

    visibleContextListChanged: (list) =>
      @visibleContextList = list
      @load() unless @hidden

    eventSaving: (event) =>
      @div.find(".#{event.id}").addClass('event_pending')

    eventSaved: =>
      @load()
