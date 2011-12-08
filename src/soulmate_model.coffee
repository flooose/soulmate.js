class Suggestion
  constructor: (id, @term, @type, @data) ->
    @element = $("#soulmate-suggestion-#{id}")
    
  select: ->
  focus: ->
  blur: ->
  render: (callback) -> 
    """
      <a class='result' href='#{@data.path}'>
        <span class='result-title'>#{@term}</span>
      </a>
    """

class SuggestionCollection
  constructor: (@renderCallback, @selectCallback) ->
    @focusedId = -1
    @types = []
    @suggestions = []
    
  update: (results) ->
    
    @types = []
    @suggestions = []
    id = 0
    
    for type, typeSuggestions of results
      @types.push( type )
      
      for suggestion in typeSuggestions
        
        @suggestions.push( new Suggestion(id, suggestion.term, suggestion.type, suggestion.data) )
        id += 1
        
  blurAll: ->
    suggestion.blur() for suggestion in @suggestions

  render: ->
    
    if @suggestions.length
    
      type = null
    
      for suggestion in @suggestions
        if suggestion.type != type
          if type != null
            @_renderTypeEnd( type )
            
          type = suggestion.type
          @_renderTypeStart( type )
          
        @_renderSuggestion( suggestion )
    
      @_renderTypeEnd(type)
  
  focus: (id) ->
    unless id < 0 || id > @suggestions.length - 1
      @suggestions[id].focus()
      @focusedIndex = id

  focusNext: ->
    @focus( @focusedId + 1 )

  focusPrevious: ->
    @focus( @focusedId - 1 )

  selectFocused: ->
    if @focusedId > 0
      @suggestions[@focusedId].select( selectCallback )
  
  # PRIVATE
  
  _renderTypeStart: (type) ->
    """
      <tr>
        <td class='results-container'>
          <div class='results'>
    """
  
  _renderTypeEnd: (type) ->
    """
          </div>
        </td>
        <td class='results-label'>#{type}</td>
      </tr>
    """
  
  _renderSuggestion: (suggestion) ->
    suggestion.render( @renderCallback )
  

class window.Soulmate

  KEYCODES = {9: 'tab', 13: 'enter', 27: 'escape', 38: 'up', 40: 'down'}
  
  constructor: (input, url, types, options) ->

    that = this
      
    @input            = input
    @url              = url
    @types            = types
    
    @maxResults       = _default( options.maxResults, 8 )
    @minQueryLength   = _default( options.minQueryLength, 1 )
    @selectSuggestionCallback = _default( options.selectSuggestionCallback, -> )
    @renderSuggestionCallback = _default( options.renderSuggestionCallback, -> )
    
    @suggestionRows     = $()
    @enabled            = false
    @lastQuery          = ''
    @focusedIndex       = -1
    @emptyQueries       = []
    @xhr                = null
  
    @input.
      keydown( @handleKeydown ).
      keyup( @handleKeyup ).
      mouseover( ->
        that.clearFocus()
      )
    
    @container = $("""
        <div id='autocomplete>
          <table>
            <tbody>
            </tbody>
          </table>
        </div>
      """
    ).insertAfter(@input)
    
    @container.delegate('.result', 'mouseover', ->
      that.focusSuggestion( that.suggestionRows.index(this) )
    })
    
  handleKeydown: (event) ->  
    
    killEvent = true
    
    switch KEYCODES[event.keyCode]

      when 'escape'
        hideContainer()

      when 'tab', 'enter'
        selectSuggestion(focusedIndex) if focusedIndex >= 0

      when 'up'
        focusPreviousSuggestion()

      when 'down'
        focusNextSuggestion()

      else
        killEvent = false

    if killEvent
      event.stopImmediatePropagation()
      event.preventDefault()
      
  handleKeyup: (event) ->
    
    query = @input.val()

    if query != lastQuery && !isEmptyQuery(query)

      lastQuery = query

      clearFocus()

      if query.length >= minQueryLength
        getSuggestions(query)

      else
        hideContainer()    
      
  _default: (input, default_value) ->
    if input? 
      input 
    else
      default_value    
    

  hideContainer: ->
    @enabled = false
    
    clearFocus()
    
    @container.hide()
    
    # Stop capturing any document click events.
    $(document).unbind('click.soulmate')

  showContainer: ->
    @enabled = true
    
    @container.show()

    # Hide the container if the user clicks outside of it.
    $(document).bind('click.soulmate', (event) ->
      @hideContainer() unless @container.has( $(event.target) ).length
    )

  selectSuggestion: (i) ->
    if i >= 0
      @selectSuggestionCallback()

  focusPreviousSuggestion: ->
    if @focusedIndex >= 0
      if @focusedIndex == 0
        @clearFocus()
      else
        @focusSuggestion(@focusedIndex - 1)

  focusNextSuggestion: ->
    if @focusedIndex < @suggestionRows.length - 1
      @focusSuggestion(@focusedIndex + 1)

  clearFocus: ->
    @focusedIndex = -1
    @suggestionRows.removeClass('focus')

  focusSuggestion: (i) ->
    @clearFocus()
    @focusedIndex = i
    @suggestionRows.eq(i).addClass('focus')

  getSuggestions = (query) ->
    
    # Cancel any previous requests if there are any.
    @xhr.abort() if @xhr?
    
    # Get the results for the given query, store in 'results'
    # and render them.
    @xhr = $.ajax({
      url: @url
      dataType: 'jsonp'
      timeout: 500
      cache: true
      data: {
        term: query
        types: @types
        limit: @maxResults
      }
      success: (data) ->
        @renderSuggestions(data.results, query)
    })

  renderSuggestions = (suggestions, query) ->

    if hasGrandChildren(suggestions)

      $containerTable.empty()

      for type, typeSuggestions of suggestions
        unless typeSuggestions.length == 0
          row = """
            <tr>
              <td class='results-container'>
                <div class='results'>
          """
          for suggestion in typeSuggestions
            row += """
                  <a class='result' href='#{suggestion.data.path}'>
                    <span class='result-title'>#{suggestion.term}</span>
                  </a>
            """
          row += """
                </div>
              </td>
              <td class='results-label'>#{type}</td>
            </tr>
          """

          $(row).appendTo($containerTable)
    
      # Identify the first fow
      $('tr', $containerTable).first().addClass('first-row')
      
      $suggestionRows = $('.result', $container)
        
      showContainer()

    else 
      emptyQueries.push(query)
      hideContainer()
      
  # Check if any attributes of an object have non-empty attributes themselves.
  hasGrandChildren = (object) ->
    for child, grandChildren of object
      return true if grandChildren.length > 0
    return false
    
  # If the query starts with any queries we have determined to have empty results
  # then it will have an empty result too, so don't bother searching for it.
  isEmptyQuery = (query) ->
    for emptyQuery in emptyQueries
      return true if startsWith(query, emptyQuery)
    return false
  
  # True if 'string' starts with 'start'
  startsWith = (string, start) ->
    string[0...start.length] == start
    
