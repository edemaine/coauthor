CodeMirror = require 'codemirror'

## The following code is originally copyright 2014 by William Stein
## [https://github.com/sagemath/cloud/blob/0233cdd61f9f81190fa5673daaac38c7fc37e821/page/misc_page.coffee#L439]
## and licensed under the BSD license
## [https://groups.google.com/forum/#!topic/codemirror/tTeNuMy58VI]

get_latex_environ = (s) ->
    i = s.indexOf('{')
    j = s.indexOf('}')
    if i != -1 and j != -1
        return escapeRegExp s.slice(i+1,j).trim()
    else
        return undefined

startswith = (s, x) ->
    if typeof(x) == "string"
        return s.indexOf(x) == 0
    else
        for v in x
            if s.indexOf(v) == 0
                return true
        return false

CodeMirror.registerGlobalHelper "fold", "tex-fold",
  ((mode) -> mode.name != 'xml'),
  (cm, start) ->
    line = cm.getLine(start.line).trimLeft()
    find_close = () ->
        BEGIN = "\\begin"
        if startswith(line, BEGIN)
            # \begin{foo}
            # ...
            # \end{foo}
            # find environment close
            environ = get_latex_environ(line.slice(BEGIN.length))
            if not environ?
                return [undefined, undefined]
            # find environment close
            END   = "\\end"
            level = 0
            begin = new RegExp("\\\\begin\\s*{#{environ}}")
            end   = new RegExp("\\\\end\\s*{#{environ}}")
            for i in [start.line..cm.lastLine()]
                cur = cm.getLine(i)
                m = cur.search(begin)
                j = cur.search(end)
                if m != -1 and (j == -1 or m < j)
                    level += 1
                if j != -1
                    level -= 1
                    if level == 0
                        return [i, j + END.length - 1]

        else if startswith(line, "\\[")
          if start.line+1 <= cm.lastLine()
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), "\\]")
                    return [i, 0]

        else if startswith(line, "\\(")
          if start.line+1 <= cm.lastLine()
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), "\\)")
                    return [i, 0]

        else if startswith(line, "\\documentclass")
          if start.line+1 <= cm.lastLine()
            # pre-amble
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), "\\begin{document}")
                    return [i - 1, 0]

        else if startswith(line, "\\chapter")
          if start.line+1 <= cm.lastLine()
            # book chapter
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), ["\\chapter", "\\end{document}"])
                    return [i - 1, 0]
          return [cm.lastLine(), 0]

        else if startswith(line, "\\section")
          if start.line+1 <= cm.lastLine()
            # article section
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), ["\\chapter", "\\section", "\\end{document}"])
                    return [i - 1, 0]
          return [cm.lastLine(), 0]

        else if startswith(line, "\\subsection")
          if start.line+1 <= cm.lastLine()
            # article subsection
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), ["\\chapter", "\\section", "\\subsection", "\\end{document}"])
                    return [i - 1, 0]
          return [cm.lastLine(), 0]
        else if startswith(line, "\\subsubsection")
          if start.line+1 <= cm.lastLine()
            # article subsubsection
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), ["\\chapter", "\\section", "\\subsection", "\\subsubsection", "\\end{document}"])
                    return [i - 1, 0]
          return [cm.lastLine(), 0]
        else if startswith(line, "\\subsubsubsection")
          if start.line+1 <= cm.lastLine()
            # article subsubsubsection
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), ["\\chapter", "\\section", "\\subsection", "\\subsubsection", "\\subsubsubsection", "\\end{document}"])
                    return [i - 1, 0]
          return [cm.lastLine(), 0]
        else if startswith(line, "%\\begin{}")
          if start.line+1 <= cm.lastLine()
            # support what texmaker supports for custom folding -- http://tex.stackexchange.com/questions/44022/code-folding-in-latex
            for i in [start.line+1..cm.lastLine()]
                if startswith(cm.getLine(i).trimLeft(), "%\\end{}")
                    return [i, 0]
        return [undefined, undefined]  # no folding here...

    [i, j] = find_close()
    if i?
        line = cm.getLine(start.line)
        k = line.indexOf("}")
        if k == -1
            k = line.length
        range =
            from : CodeMirror.Pos(start.line, k+1)
            to   : CodeMirror.Pos(i, j)
        return range
    else
        # nothing to fold
        return undefined
