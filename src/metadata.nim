import strutils, times, parseutils

type
  TArticleMetadata* = object
    title*: string
    date*: TTimeInfo
    tags*: seq[string]
    isDraft*: bool
    body*: string

proc parseDate(val: string): TTimeInfo =
  # YYYY-mm-dd hh:mm
  var i = 0
  var
    year = ""
    month = ""
    day = ""
    hour = ""
    minute = ""
  i.inc parseUntil(val, year, '-', i)
  i.inc
  i.inc parseUntil(val, month, '-', i)
  i.inc
  i.inc parseUntil(val, day, ' ', i)
  i.inc
  i.inc parseUntil(val, hour, ':', i)
  i.inc
  minute = val[i .. -1]
  result.year = parseInt(year)
  result.month = (parseInt(month)-1).TMonth
  result.monthday = parseInt(day)
  result.hour = parseInt(hour)
  result.minute = parseInt(minute)
  result.tzname = "UTC"
  let t = TimeInfoToTime(result)
  result = getGMTime(t)

proc parseMetadata*(filename: string): TArticleMetadata =
  let article = readFile(filename)
  var i = 0
  i.inc skip(article, "---", i)
  if i == 0:
    raise newException(EInvalidValue,
          "Article must begin with '---' signifying meta data.")
  i.inc skipWhitespace(article, i)
  while true:
    if article[i .. i + 2] == "---": break
    if article[i] == '#':
      i.inc skipUntil(article, Whitespace - {' '}, i)
      i.inc skipWhitespace(article, i)
      continue
    
    var key = ""
    i.inc parseUntil(article, key, {':'} + Whitespace, i)
    if article[i] != ':':
      raise newException(EInvalidValue, "Expected ':' after key in meta data.")
    i.inc # skip :
    i.inc skipWhitespace(article, i)
    
    var value = ""
    i.inc parseUntil(article, value, Whitespace - {' '}, i)
    i.inc skipWhitespace(article, i)
    case key.normalize
    of "title":
      result.title = value
      if result.title[0] == '"' and result.title[result.title.len-1] == '"':
        result.title = result.title[1 .. -2]
    of "date":
      result.date = parseDate(value)
    of "tags":
      result.tags = @[]
      for i in value.split(','):
        result.tags.add(i.strip)
    of "draft":
      let vn = value.normalize
      result.isDraft = vn in ["t", "true", "y", "yes"]
    else:
      raise newException(EInvalidValue, "Unknown key: " & key)
  i.inc 3 # skip ---
  i.inc skipWhitespace(article, i)
  result.body = article[i .. -1]