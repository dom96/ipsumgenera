# Copyright (C) 2013 Dominik Picheta
# Licensed under MIT license.

import os, times, strutils, algorithm, strtabs, parseutils, tables, xmltree

import src/metadata, src/rstrender, src/config

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

proc normalizeTag(tag: string): string =
  result = ""
  for i in tag:
    case i
    of ' ':
      result.add '-'
    else:
      result.add i.toLower()

proc joinUrl(x: varargs[string]): string =
  result = ""
  for i in x:
    var cleanI = i
    if cleanI[0] == '/': cleanI = cleanI[1 .. -1]
    if cleanI.endsWith("/"): cleanI = cleanI[0 .. -2]

    result.add "/" & cleanI
  result = result[1 .. -1] # Get rid of the / at the start.

proc genUrl(article: TArticleMetadata): string =
  # articles/2013/03/title.html
  joinUrl("articles", format(article.date, "yyyy/MM"),
    article.title.normalizeTitle() & ".html")

proc findArticles(): seq[string] =
  result = @[]
  var dir = getCurrentDir() / "articles"
  for f in walkFiles(dir / "*.rst"):
    result.add(f)

include "layouts/articles.html" # TODO: Rename to articlelist.html?
include "layouts/atom.xml"

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

proc createKeys(otherKeys: varargs[tuple[k, v: string]],
                cfg: TConfig): PStringTable =
  result = newStringTable({"blog_title": cfg.title, "blog_url": cfg.url,
      "blog_author": cfg.author})
  for i in otherKeys:
    result[i.k] = i.v

proc generateDefault(mds: seq[TArticleMetadata], cfg: TConfig) =
  let def = readFile(getCurrentDir() / "layouts" / "default.html")
  let output = replaceKeys(def,
      {"body": renderArticles(mds, ""), "prefix": ""}.createKeys(cfg))
  writeFile(getCurrentDir() / "output" / "index.html", output)

const
  articlePagePrefix = "../../../"
  tagPagePrefix = "../"

proc generateArticle(filename: string, meta: TArticleMetadata,
                     cfg: TConfig) =
  let def = readFile(getCurrentDir() / "layouts" / "article.html")
  let date = format(meta.date, "dd/MM/yyyy HH:mm")
  let tags = renderTags(meta.tags, articlePagePrefix)
  let output = replaceKeys(def,
      {"title": meta.title, "date": date, 
       "body": renderRst(meta.body, articlePagePrefix),
       "prefix": articlePagePrefix, "tags": tags}.createKeys(cfg))
  let path = getCurrentDir() / "output" / genURL(meta)
  createDir(path.splitFile.dir)
  
  writeFile(path, output)

proc sortArticles(articles: var seq[TArticleMetadata]) =
  articles.sort do (x, y: TArticleMetadata) -> int:
    if TimeInfoToTime(x.date) > TimeInfoToTime(y.date):
      -1
    elif TimeInfoToTime(x.date) == TimeInfoToTime(y.date):
      0
    else:
      1

proc processArticles(cfg: TConfig): seq[TArticleMetadata] =
  result = @[]
  let articleFilenames = findArticles()
  for i in articleFilenames:
    echo("Processing ", i)
    let meta = parseMetadata(i)
    if not meta.isDraft:
      result.add(meta)
    else:
      echo("  Article is a draft, omitting from article list.")
    generateArticle(i, meta, cfg)

  # Sort articles from newest to oldest.
  sortArticles(result)

proc generateTagPages(meta: seq[TArticleMetadata], cfg: TConfig) =
  var tags = initTable[string, seq[TArticleMetadata]]()
  for a in meta:
    for t in a.tags:
      let nt = t.normalizeTag
      if not tags.hasKey(nt):
        tags[nt] = @[]
      tags.mget(nt).add(a)
  
  let templ = readFile(getCurrentDir() / "layouts" / "tag.html")
  createDir(getCurrentDir() / "output" / "tags")
  for tag, articles in tags:
    var sorted = articles
    sortArticles(sorted)
    let output = replaceKeys(templ,
      {"body": renderArticles(sorted, tagPagePrefix), "tag": tag,
       "prefix": tagPagePrefix}.createKeys(cfg))
    writeFile(getCurrentDir() / "output" / "tags" /
              tag.addFileExt("html"), output)

proc generateAtomFeed(meta: seq[TArticleMetadata], cfg: TConfig) =
  let feed = renderAtom(meta, cfg.title, cfg.url, joinUrl(cfg.url, "feed.xml"),
                        cfg.author)
  writeFile(getCurrentDir() / "output" / "feed.xml", feed)

when isMainModule:
  let cfg = parseConfig(getCurrentDir() / "ipsum.ini")
  createDir(getCurrentDir() / "output")
  let articles = processArticles(cfg)
  generateDefault(articles, cfg)
  generateTagPages(articles, cfg)
  generateAtomFeed(articles, cfg)