import strutils, times, parseutils, os

type
  TArticleMetadata* = object
    title*: string
    pubDate*: DateTime
    modDate*: DateTime
    tags*: seq[string]
    isDraft*: bool
    body*: string
  MetadataInProgress = object
    data: TArticleMetadata
    progress: int
    title: bool
    pubDate: bool
    modDate: bool
    tags: bool
    isDraft: bool
    body: bool

proc parseDate(val: string): DateTime =
  parse(val, "yyyy-MM-dd HH:mm:ss", utc())

proc parseMetadata*(filename: string): TArticleMetadata =
  var meta = MetadataInProgress(data: TArticleMetadata(pubDate: now(), modDate: now()))
  template `:=`(a, b: untyped): untyped =
    assert(not meta.a)
    meta.data.a = b
    meta.a = true
    inc meta.progress

  let article = readFile(filename)
  var i = 0
  i.inc skip(article, "---", i)
  if i == 0:
    raise newException(ValueError,
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
      raise newException(ValueError, "Expected ':' after key in meta data.")
    i.inc # skip :
    i.inc skipWhitespace(article, i)
    
    var value = ""
    i.inc parseUntil(article, value, Whitespace - {' '}, i)
    i.inc skipWhitespace(article, i)
    case key.normalize
    of "title":
      if value[0] == '"' and value[^1] == '"':
        value = value[1 .. ^2]
      title := value
    of "date", "pubdate":
      pubDate := parseDate(value)
    of "moddate":
      modDate := parseDate(value)
    of "tags":
      tags := @[]
      for i in value.split(','):
        meta.data.tags.add(i.strip)
    of "draft":
      let vn = value.normalize
      isDraft := vn in ["t", "true", "y", "yes"]
    else:
      raise newException(ValueError, "Unknown key: " & key)
  i.inc 3 # skip ---
  i.inc skipWhitespace(article, i)
  body := article[i .. ^1]
  # Give last modification date as file timestamp if nothing else was found.
  if not meta.modDate:
    modDate := filename.getLastModificationTime.utc

  doAssert(meta.progress == 6 or (meta.progress == 5 and not meta.isDraft))
  return meta.data
