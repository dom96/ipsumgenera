import os, times, strutils, algorithm

import src/metadata, src/rstrender

const
  

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

proc generateDefault(mds: seq[TArticleMetadata]) =
  let def = readFile(getCurrentDir() / "layouts" / "default.html")
  let output = def % [renderArticles(mds)]
  writeFile(getCurrentDir() / "output" / "index.html", output)

proc generateArticle(filename: string, meta: TArticleMetadata, metadataEnd: int) =
  let def = readFile(getCurrentDir() / "layouts" / "article.html")
  let date = format(meta.date, "dd/MM/yyyy hh:mm")
  let rst = readFile(filename)[metadataEnd .. -1]
  let output = def % [meta.title, date, renderRst(rst)]
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