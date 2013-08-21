import parsecfg, streams, strutils

type
  TConfig* = object
    title*: string
    url*: string
    author*: string

proc initConfig(): TConfig =
  result.title = ""
  result.url = ""
  result.author = ""

proc validateConfig(config: TConfig) =
  template ra(field: string) =
    raise newException(EInvalidValue,
      "You need to specify the '$1' field in the config." % field)
  if config.title == "":
    ra("title")
  if config.author == "":
    ra("author")
  if config.url == "":
    ra("url")

proc parseConfig*(filename: string): TConfig =
  result = initConfig()
  var file = newFileStream(filename, fmRead)
  var cfg: TCfgParser
  open(cfg, file, filename)
  while true:
    let ev = cfg.next()
    case ev.kind
    of cfgSectionStart:
      raise newException(EInvalidValue, "No sections supported.")
    of cfgKeyValuePair, cfgOption:
      case ev.key
      of "title":
        result.title = ev.value
      of "url":
        result.url = ev.value
      of "author":
        result.author = ev.value
    of cfgError:
      raise newException(EInvalidValue, ev.msg)
    of cfgEof:
      break
  cfg.close()
  file.close()
  validateConfig(result)