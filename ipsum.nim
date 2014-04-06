# Copyright (C) 2013 Dominik Picheta
# Licensed under MIT license.

import os, times, strutils, algorithm, strtabs, parseutils, tables, xmltree,
  sequtils

import src/metadata, src/rstrender, src/config

const
  articleDir = "articles"
  outputDir = "output"
  staticDir = "static"
  tagPagePrefix = "../"


proc normalizeTitle(title: string): string =
  result = ""
  for i in title:
    case i
    of ':', '-', '=', '*', '^', '%', '$', '#', '@', '!', '{', '}', '[', ']',
       '<', '>', ',', '.', '?', '|', '~', '\\', '/', '"', '\'':
      discard
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
  joinUrl(articleDir, format(article.pubDate, "yyyy/MM"),
    article.title.normalizeTitle() & ".html")

proc escapePath(s: string): string =
  ## Escapes a path to be valid according to RFC 3987.
  ##
  ## This proc does not perform the full work of parsing and filtering a full
  ## IRI, it is only used to filter local filename paths and escape their
  ## possible unicode characters for inclusion as rss identifiers. If you pass
  ## a full absolute URL, the scheme part will be malformed. A full correct
  ## implementation would handle the different parts of the URL correctly.
  ##
  ## This is a variation of the algorithm found in cgi.URLencode. Unicode
  ## characters are parsed correctly because Nimrod strings happen to be
  ## encoded in UTF8 and the rfc specifies that the encoded bytes need to
  ## translated to %HH format.
  result = newStringOfCap(s.len + s.len shr 2) # assume 12% non-alnum-chars
  for i in 0..s.len-1:
    case s[i]
    of 'a'..'z', 'A'..'Z', '0'..'9', '-', '.', '~', '/', '_': add(result, s[i])
    else:
      add(result, '%')
      add(result, toHex(ord(s[i]), 2))

proc findArticles(): seq[string] =
  result = @[]
  var dir = getCurrentDir() / articleDir
  for f in walkFiles(dir / "*.rst"):
    result.add(f)

proc findStaticFiles(): seq[string] =
  ## Returns a list of files in the static subdirectory.
  ##
  ## Unlike findArticles, the returned paths are not absoulte, they are
  ## relative to the static directory. You need to prefix the results with
  ## staticDir to reach the file.
  result = @[]
  const valid = {pcFile, pcLinkToFile, pcDir, pcLinkToDir}
  let pruneLen = staticDir.len
  for f in walkDirRec(staticDir, valid):
    assert f.len > pruneLen + 1
    result.add(f[pruneLen + 1 .. <f.len])

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

proc needsRefresh*(target: string, src: varargs[string]): bool =
  ## Returns true if target is missing or src has newer modification date.
  ##
  ## Copied from
  ## https://github.com/fowlmouth/nake/blob/078a99849a29a890fc22a14173ca4591a14dea86/nake.nim#L150
  assert len(src) > 0, "Pass some parameters to check for"
  var targetTime: float
  try:
    targetTime = toSeconds(getLastModificationTime(target))
  except EOS:
    return true

  for s in src:
    let srcTime = toSeconds(getLastModificationTime(s))
    if srcTime > targetTime:
      return true


proc generateArticle(filename, dest, style: string, meta: TArticleMetadata,
                     cfg: TConfig) =
  ## Generates an html file from the rst `filename`.
  ##
  ## Pass as `dest` the relative final path of the input `filename`. `style` is
  ## the name of one of the files in th layouts subdirectory.
  let
    def = readFile(getCurrentDir() / "layouts" / style)
    pubDate = format(meta.pubDate, "dd/MM/yyyy HH:mm")
    modDate = format(meta.modDate, "dd/MM/yyyy HH:mm")
  # Calculate prefix depending on the depth of `dest`.
  var prefix = ""
  for i in parentDirs(dest, inclusive = false): prefix = prefix / ".."
  if prefix.len > 0: prefix.add(dirSep)
  let tags = renderTags(meta.tags, prefix)
  let output = replaceKeys(def,
      {"title": meta.title, "date": pubDate, "pubDate": pubDate,
       "modDate": modDate, "body": renderRst(meta.body, prefix),
       "prefix": prefix, "tags": tags}.createKeys(cfg))
  let path = getCurrentDir() / outputDir / dest
  createDir(path.splitFile.dir)
  
  writeFile(path, output)

proc processStatic(cfg: TConfig): seq[TArticleMetadata] =
  ## Processes files found in the static subdirectory.
  ##
  ## Non rst files will be copied as is, rst files will be processed with the
  ## static template.
  ##
  ## The proc will return the list of the metadata for parsed rst files.
  result = @[]
  let staticFilenames = findStaticFiles()
  for i in staticFilenames:
    let
      src = staticDir / i
      ext = i.splitFile.ext.toLower
    if ext == ".rst":
      let dest = changeFileExt(i, "html")
      echo("Processing ", getCurrentDir() / outputDir / dest)
      let meta = parseMetadata(src)
      if meta.isDraft:
        echo("  Article is a draft, omitting from article list.")
        continue
      result.add(meta)
      generateArticle(src, dest, "static.html", meta, cfg)
    else:
      let dest = getCurrentDir() / outputDir / i
      if dest.needsRefresh(src):
        echo "Copying ", dest
        createDir(dest.splitFile.dir)
        copyFileWithPermissions(src, dest)

proc generateDefault(mds: seq[TArticleMetadata], cfg: TConfig) =
  let def = readFile(getCurrentDir() / "layouts" / "default.html")
  let output = replaceKeys(def,
      {"body": renderArticles(mds, ""), "prefix": ""}.createKeys(cfg))
  writeFile(getCurrentDir() / outputDir / "index.html", output)

proc sortArticles(articles: var seq[TArticleMetadata]) =
  articles.sort do (x, y: TArticleMetadata) -> int:
    if TimeInfoToTime(x.pubDate) > TimeInfoToTime(y.pubDate):
      -1
    elif TimeInfoToTime(x.pubDate) == TimeInfoToTime(y.pubDate):
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
    generateArticle(i, genURL(meta), "article.html", meta, cfg)

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
  createDir(getCurrentDir() / outputDir / "tags")
  for tag, articles in tags:
    var sorted = articles
    sortArticles(sorted)
    let output = replaceKeys(templ,
      {"body": renderArticles(sorted, tagPagePrefix), "tag": tag,
       "prefix": tagPagePrefix}.createKeys(cfg))
    writeFile(getCurrentDir() / outputDir / "tags" /
              tag.addFileExt("html"), output)

proc generateAtomFeed(meta: seq[TArticleMetadata], cfg: TConfig) =
  # Prunes the article sequence according to the configuration limit.
  assert cfg.numRssEntries >= 0
  var meta = meta
  if meta.len > cfg.numRssEntries:
    meta.delete(cfg.numRssEntries + 1, <meta.len)
  let feed = renderAtom(meta, cfg.title, cfg.url, joinUrl(cfg.url, "feed.xml"),
                        cfg.author)
  writeFile(getCurrentDir() / outputDir / "feed.xml", feed)

when isMainModule:
  let cfg = parseConfig(getCurrentDir() / "ipsum.ini")
  createDir(getCurrentDir() / outputDir)
  let
    staticMetadata = processStatic(cfg)
    blogMetadata = processArticles(cfg)
  generateDefault(blogMetadata, cfg)
  generateTagPages(concat(blogMetadata, staticMetadata), cfg)
  generateAtomFeed(blogMetadata, cfg)
