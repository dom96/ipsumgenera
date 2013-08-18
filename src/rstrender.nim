import rst, rstast, strutils, htmlgen, highlite, xmltree

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

proc renderRst(node: PRstNode): string =
  result = ""
  proc renderSons(father: PRstNode): string =
    result = ""
    for i in father.sons:
      result.add renderRst(i)
  
  case node.kind
  of rnInner:
    result.add renderSons(node)
  of rnParagraph:
    result.add p(renderSons(node)) & "\n"
  of rnLeaf:
    result.add node.text
  of rnStandaloneHyperlink:
    let hyper = renderSons(node)
    result.add a(href=hyper, hyper)
  of rnHyperLink:
    result.add a(href=renderSons(node.sons[1]), renderSons(node.sons[0]))
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
    result.add span(class="literal", renderSons(node))
  of rnCodeBlock:
    result.add renderCodeBlock(node)
  else:
    echo(node.kind)
    assert false

proc renderRst*(text: string, filename = ""): string =
  result = ""
  var hasToc = false
  var ast = rstParse(text, filename, 0, 0, hasToc,
                     {roSupportRawDirective, roSupportMarkdown})
  #echo strRst(ast)
  result = renderRst(ast)

when isMainModule:
  import os, metadata
  var i = 0
  var filename = getCurrentDir().parentDir() / "articles" / "2013-03-13-gtk-plus-a-method-to-guarantee-scrolling.rst"
  discard parseMetadata(filename, i)
  echo renderRst(readFile(filename)[i .. -1], filename)