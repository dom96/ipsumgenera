import os, times, strutils, algorithm, strtabs, parseutils

import src/metadata, src/rstrender

proc normalizeTitle(title: string): string =
  result = ""
  for i in title:
    case i
    of ':', '-', '=', '*', '^', '%', '$', '#', '@', '!', '{', '}', '[', ']',
       '<', '>', ',', '.', '?', '|', '~', '\\', '/', '"', '\'':
      nil
    of '&': result.add "-and-"
    of '+': result.add "-plus-"
    of ' ': result.add '-'
    else:
      result.add i.toLower()

proc genURL(article: TArticleMetadata): string =
  # articles/2013/03/title.html
  "articles/" & format(article.date, "yyyy/MM/") &
    article.title.normalizeTitle() & ".html"

proc findArticles(): seq[string] =
  result = @[]
  var dir = getCurrentDir() / "articles"
  for f in walkFiles(dir / "*.rst"):
    result.add(f)

include "layouts/articles.html" # TODO: Rename to articlelist.html?

proc replaceKeys(s: string, kv: PStringTable): string =
  result = ""
  var i = 0
  while true:
    case s[i]
    of '\\':
      if s[i+1] == '$':
        result.add("$")
        i.inc 2
      else:
        result.add(s[i])
        i.inc
    of '$':
      assert s[i+1] == '{'
      let key = captureBetween(s, '{', '}', i)
      if not hasKey(kv, key):
        raise newException(EInvalidValue, "Key not found: " & key)
      result.add(kv[key])
      i.inc key.len + 3
    of '\0':
      break
    else:
      result.add s[i]
      i.inc

proc generateDefault(mds: seq[TArticleMetadata]) =
  let def = readFile(getCurrentDir() / "layouts" / "default.html")
  let output = replaceKeys(def,
      {"body": renderArticles(mds), "prefix": ""}.newStringTable())
  writeFile(getCurrentDir() / "output" / "index.html", output)

proc generateArticle(filename: string, meta: TArticleMetadata, metadataEnd: int) =
  let def = readFile(getCurrentDir() / "layouts" / "article.html")
  let date = format(meta.date, "dd/MM/yyyy hh:mm")
  let rst = readFile(filename)[metadataEnd .. -1]
  let output = replaceKeys(def,
      {"title": meta.title, "date": date, "body": renderRst(rst),
       "prefix": "../../../"}.newStringTable())
  let path = getCurrentDir() / "output" / genURL(meta)
  createDir(path.splitFile.dir)
  
  writeFile(path, output)
  
proc processArticles(): seq[TArticleMetadata] =
  result = @[]
  let articleFilenames = findArticles()
  for i in articleFilenames:
    var metadataEnd = 0
    echo("Processing ", i)
    let meta = parseMetadata(i, metadataEnd)
    result.add(meta)
    generateArticle(i, meta, metadataEnd)

  # Sort articles from newest to oldest.
  result.sort do (x, y: TArticleMetadata) -> int:
    if TimeInfoToTime(x.date) > TimeInfoToTime(y.date):
      -1
    elif TimeInfoToTime(x.date) == TimeInfoToTime(y.date):
      0
    else:
      1

when isMainModule:
  createDir(getCurrentDir() / "output")
  generateDefault(processArticles())