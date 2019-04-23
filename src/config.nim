import parsecfg, streams, strutils, os

type
  TConfig* = object
    title*: string
    url*: string
    author*: string
    numRssEntries*: int

proc initConfig(): TConfig =
  result.title = ""
  result.url = ""
  result.author = ""
  result.numRssEntries = 10

proc validateConfig(config: TConfig) =
  template ra(field: string) =
    raise newException(ValueError,
      "You need to specify the '$1' field in the config." % field)
  if config.title == "":
    ra("title")
  if config.author == "":
    ra("author")
  if config.url == "":
    ra("url")
  if config.numRssEntries < 0:
    raise newException(ValueError,
      "The numRssEntries value can't be negative.")

proc parseConfig*(filename: string): TConfig =
  if not filename.existsFile:
    raise newException(ValueError, "Missing '" & filename & "'")
  result = initConfig()
  var file = newFileStream(filename, fmRead)
  var cfg: CfgParser
  open(cfg, file, filename)
  while true:
    let ev = cfg.next()
    case ev.kind
    of cfgSectionStart:
      raise newException(ValueError, "No sections supported.")
    of cfgKeyValuePair, cfgOption:
      case ev.key.normalize
      of "title":
        result.title = ev.value
      of "url":
        result.url = ev.value
      of "author":
        result.author = ev.value
      of "numrssentries":
        result.numRssEntries = ev.value.parseInt
    of cfgError:
      raise newException(ValueError, ev.msg)
    of cfgEof:
      break
  cfg.close()
  file.close()
  validateConfig(result)
