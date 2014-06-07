import rst, rstast, strutils, htmlgen, highlite, xmltree, strtabs, os

proc strRst(node: PRstNode, indent: int = 0): string =
  ## Internal proc for debugging.
  result = ""
  result.add(repeatChar(indent) & $node.kind & "(t: " & (if node.text != nil: node.text else: "") & ", l=" & $node.level & ")" & "\n")
  if node.sons.len > 0:
    for i in node.sons:
      if i == nil:
        result.add(repeatChar(indent + 2) & "NIL SON!!!\n"); continue
      result.add strRst(i, indent + 2)

proc renderCodeBlock(n: PRstNode): string =
  ## Renders a block with code syntax highlighting.
  result = ""
  if n.sons[2] == nil: return
  var m = n.sons[2].sons[0]
  assert m.kind == rnLeaf
  var langstr = strip(getArgument(n))
  var lang: TSourceLanguage
  if langstr == "":
    lang = langNimrod # default language
  else:
    lang = getSourceLanguage(langstr)
  
  result.add "<pre class='code'>"
  if lang == langNone:
    echo("[Warning] Unsupported language: " & langstr)
    result.add(xmltree.escape(m.text))
  else:
    var g: TGeneralTokenizer
    initGeneralTokenizer(g, m.text)
    while true:
      getNextToken(g, lang)
      case g.kind
      of gtEof: break
      of gtNone, gtWhitespace:
        add(result, substr(m.text, g.start, g.length + g.start - 1))
      else:
        result.add span(class=tokenClassToStr[g.kind],
            xmltree.escape(substr(m.text, g.start, g.length+g.start-1)))
    deinitGeneralTokenizer(g)
  result.add "</pre>"

proc renderLiteralBlock(n: PRstNode): string =
  ## Renders a plain literal block.
  result = ""
  if len(n.sons) < 1: return
  result.add "<pre class='literal'>"
  for m in n.sons:
    assert m.kind == rnLeaf
    result.add(xmltree.escape(m.text))
  result.add "</pre>"

proc renderRawDirective(n: PRstNode): string =
  ## Renders all children leaf nodes as plain text without escaping.
  ##
  ## rnDirArg nodes are not rendered but verified to contain the string html.
  ## If the string doesn't match, the rest of the tree is ignored and the proc
  ## returns immediately.
  result = ""
  for i in n.sons:
    if not i.isNil():
      case i.kind
      of rnLeaf:
        assert (not i.text.isNil)
        result.add(i.text)
      of rnDirArg:
        assert i.sons.len == 1
        assert i.sons[0].kind == rnLeaf
        assert (not i.sons[0].text.isNil)
        let params = i.sons[0].text
        if params != "html":
          echo("Ignoring raw directive block '", params, "'")
          return
      else:
        result.add renderRawDirective(i)

proc renderPrefixUrl(url, articlePrefix, absoluteUrls: string): string =
  ## Adds a prefix to an url, optionally making it absolute.
  ##
  ## Returns `url` with instances of the ``${prefix}`` substring replaced with
  ## `articlePrefix`.
  ##
  ## Additinally, if `absoluteUrls` is not the empty string, the resulting
  ## value is checked for being an absolute path. If it is a relative path, it
  ## will be *joined* with `absoluteUrls`.
  result = url.replace("${prefix}", articlePrefix)
  # Avoid absoluteUrls replacement if nil or emtpy string.
  if absoluteUrls.isNil or absoluteUrls.len < 1: return
  # Discard absolute urls using domain relative paths (aka "/foo/bar")
  if result.len < 1 or result[0] == '/': return
  # Discard absolute urls which contain the substring ":/".
  let first = result.find({'/', ':'})
  if first > 0 and first + 1 < result.len and
      result[first] == ':' and result[first+1] == '/':
    return
  # If we reached here, it is a relative path.
  result = absoluteUrls/result


proc renderRst(node: PRstNode, articlePrefix, absoluteUrls: string): string
proc getFieldList(node: PRstNode,
                  articlePrefix, absoluteUrls: string): PStringTable =
  assert node.kind == rnFieldList
  result = newStringTable()
  for field in node.sons:
    assert field.kind == rnField
    assert field.sons[0].kind == rnFieldName
    assert field.sons[1].kind == rnFieldBody
    let name = renderRst(field.sons[0], articlePrefix, absoluteUrls)
    let value = renderRst(field.sons[1], articlePrefix, absoluteUrls)
    result[name] = value

proc renderRst(node: PRstNode, articlePrefix, absoluteUrls: string): string =
  result = ""
  proc renderSons(father: PRstNode): string =
    result = ""
    for i in father.sons:
      if not i.isNil():
        result.add renderRst(i, articlePrefix, absoluteUrls)
  
  case node.kind
  of rnInner:
    result.add renderSons(node)
  of rnParagraph:
    result.add p(renderSons(node)) & "\n"
  of rnLeaf:
    result.add(xmltree.escape(node.text))
  of rnStandaloneHyperlink:
    let hyper = renderSons(node).renderPrefixUrl(articlePrefix, absoluteUrls)
    result.add a(href=hyper, hyper)
  of rnHyperLink:
    let hyper = renderSons(node.sons[1]).renderPrefixUrl(articlePrefix,
                                                         absoluteUrls)
    result.add a(href=hyper, renderSons(node.sons[0]))
  of rnEmphasis:
    result.add span(style="font-style: italic;", renderSons(node))
  of rnStrongEmphasis:
    result.add span(style="font-weight: bold;", renderSons(node))
  of rnHeadline:
    case node.level
    of 1:
      result.add h1(renderSons(node))
    of 2:
      result.add h2(renderSons(node))
    of 3:
      result.add h3(renderSons(node))
    else:
      assert false, "Unknown headline level: " & $node.level
  of rnInlineLiteral:
    result.add code(renderSons(node))
  of rnLiteralBlock:
    result.add renderLiteralBlock(node)
  of rnCodeBlock:
    result.add renderCodeBlock(node)
  of rnTransition:
    result.add hr()
  of rnBlockquote:
    result.add blockquote(renderSons(node))
  of rnEnumList:
    result.add ol(renderSons(node))
  of rnBulletList:
    result.add ul(renderSons(node))
  of rnBulletItem, rnEnumItem:
    result.add li(renderSons(node))
  of rnImage:
    let src = renderSons(node.sons[0]).renderPrefixUrl(articlePrefix,
                                                       absoluteUrls)
    if not node.sons[1].isNil() and node.sons[1].kind == rnFieldList:
      let fieldList = getFieldList(node.sons[1], articlePrefix, absoluteUrls)
      var style = ""
      for k, v in pairs(fieldList):
        case k
        of "height", "width":
          style.add("$1: $2;" % [k, v])
        else: raise newException(EInvalidValue, "Invalid field name for image.")
      result.add "<img src='$1' style='$2'/>" % [src, style]
    else:
      result.add img(src=src, alt="")
  of rnFieldName, rnFieldBody:
    result.add(renderSons(node))
  of rnRawHtml:
    result.add(renderRawDirective(node))
  of rnTable:
    result.add "<table border=\"1\" class=\"docutils\">"
    result.add renderSons(node)
    result.add "</table>"
  of rnTableRow:
    result.add "<tr>"
    result.add renderSons(node)
    result.add "<tr>\n"
  of rnTableDataCell:
    result.add "<td>"
    result.add renderSons(node)
    result.add "<td>\n"
  of rnTableHeaderCell:
    result.add "<th>"
    result.add renderSons(node)
    result.add "<th>\n"
  else:
    echo("Unknown node kind in rst: ", node.kind)
    doAssert false

proc renderRst*(text: string, articlePrefix: string, filename = "",
                absoluteUrls = ""): string =
  ## Returns the rst `text` string as rendered HTML.
  ##
  ## The `articlePrefix` string will replace strings in the form ${prefix} in
  ## the urls found in the rst `text`. You can pass here the absolute root URL
  ## to where you will place all the generated HTML files so that you can write
  ## links in the form ``${prefix}images/smiley.gif`` and they will resolve
  ## correctly from every subdirectory.
  ##
  ## The `filename` parameter is used for ornamental purposes, if something
  ## fails it will be displayed to the user there, but otherwise serves no real
  ## purpose.
  ##
  ## The `absoluteUrls` is only used for RSS HTML generation. Different RSS
  ## readers have different behaviours when resolving relative URLs, so if you
  ## write a relative link to another article, most likely the RSS reader will
  ## build an incorrect absolute URL. To avoid this, pass the absolute URL for
  ## the directory where the generated HTML will be placed, and it will be
  ## prepended automatically to all relative links. If you are generating
  ## standalone HTML, pass the empty string to leave relative link unmodified.
  var hasToc = false
  var ast = rstParse(text, filename, 0, 0, hasToc,
                     {roSupportRawDirective, roSupportMarkdown})
  #echo strRst(ast)
  result = renderRst(ast, articlePrefix, absoluteUrls)

when isMainModule:
  import os, metadata
  var i = 0
  var filename = getCurrentDir().parentDir() / "articles" / "2013-03-13-gtk-plus-a-method-to-guarantee-scrolling.rst"
  discard parseMetadata(filename, i)
  echo renderRst(readFile(filename)[i .. -1], filename)
