import rst, rstast, strutils, htmlgen, highlite, xmltree, strtabs

proc strRst(node: PRstNode, indent: int = 0): string =
  result = ""
  result.add(repeatChar(indent) & $node.kind & "(t: " & (if node.text != nil: node.text else: "") & ", l=" & $node.level & ")" & "\n")
  if node.sons.len > 0:
    for i in node.sons:
      if i == nil:
        result.add(repeatChar(indent + 2) & "NIL SON!!!\n"); continue
      result.add strRst(i, indent + 2)

proc renderCodeBlock(n: PRstNode): string =
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
    result.add(m.text)
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

proc renderRst(node: PRstNode, articlePrefix: string): string
proc getFieldList(node: PRstNode, articlePrefix: string): PStringTable =
  assert node.kind == rnFieldList
  result = newStringTable()
  for field in node.sons:
    assert field.kind == rnField
    assert field.sons[0].kind == rnFieldName
    assert field.sons[1].kind == rnFieldBody
    let name = renderRst(field.sons[0], articlePrefix)
    let value = renderRst(field.sons[1], articlePrefix)
    result[name] = value

proc renderRst(node: PRstNode, articlePrefix: string): string =
  result = ""
  proc renderSons(father: PRstNode): string =
    result = ""
    for i in father.sons:
      if not i.isNil():
        result.add renderRst(i, articlePrefix)
  
  case node.kind
  of rnInner:
    result.add renderSons(node)
  of rnParagraph:
    result.add p(renderSons(node)) & "\n"
  of rnLeaf:
    result.add node.text
  of rnStandaloneHyperlink:
    let hyper = renderSons(node).replace("${prefix}", articlePrefix)
    result.add a(href=hyper, hyper)
  of rnHyperLink:
    let hyper = renderSons(node.sons[1]).replace("${prefix}", articlePrefix)
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
  of rnCodeBlock:
    result.add renderCodeBlock(node)
  of rnTransition:
    result.add hr()
  of rnBlockquote:
    result.add blockquote(renderSons(node))
  of rnBulletList:
    result.add ul(renderSons(node))
  of rnBulletItem:
    result.add li(renderSons(node))
  of rnImage:
    let src = renderSons(node.sons[0]).replace("${prefix}", articlePrefix)
    if not node.sons[1].isNil() and node.sons[1].kind == rnFieldList:
      let fieldList = getFieldList(node.sons[1], articlePrefix)
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
  else:
    echo("Unknown node kind in rst: ", node.kind)
    doAssert false

proc renderRst*(text: string, articlePrefix: string, filename = ""): string =
  result = ""
  var hasToc = false
  var ast = rstParse(text, filename, 0, 0, hasToc,
                     {roSupportRawDirective, roSupportMarkdown})
  #echo strRst(ast)
  result = renderRst(ast, articlePrefix)

when isMainModule:
  import os, metadata
  var i = 0
  var filename = getCurrentDir().parentDir() / "articles" / "2013-03-13-gtk-plus-a-method-to-guarantee-scrolling.rst"
  discard parseMetadata(filename, i)
  echo renderRst(readFile(filename)[i .. -1], filename)