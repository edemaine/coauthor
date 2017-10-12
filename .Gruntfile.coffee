module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    copy:
      katex_fonts:
        expand: true
        cwd: 'node_modules/katex/dist/fonts/'
        src: '**'
        dest: 'public/katex/fonts/'
      codemirror:
        expand: true
        flatten: true
        src: [
          'node_modules/codemirror/theme/blackboard.css'
          'node_modules/codemirror/theme/eclipse.css'
          'node_modules/codemirror/addon/dialog/dialog.css'
          'node_modules/codemirror/addon/fold/foldgutter.css'
        ]
        dest: 'client/codemirror/'
    replace:
      katex:
        options:
          patterns: [
            match: /url\(fonts/g
            replacement: 'url(/katex/fonts'
          ]
        files: [
          expand: true
          flatten: true
          src: 'node_modules/katex/dist/katex.min.css'
          dest: 'client/'
        ]
      codemirror:
        options:
          patterns: [
            match: /require\(".\/codemirror"\)/
            replacement: 'require("meteor/edemaine:sharejs-codemirror/node_modules/codemirror/lib/codemirror.js")'
          ,
            match: /require\("[^"]*\//g
            replacement: 'require("./'
          #  match: /\(function[^]*?function\(CodeMirror\) {/
          #  replacement: 'const CodeMirror = require("meteor/edemaine:sharejs-codemirror/node_modules/codemirror/lib/codemirror.js");'
          #,
          #  match: /}\);\s*$/
          #  replacement: ''
          ,
            match: /\|coap\|/
            replacement: '|coap|coauthor|'
          ]
        files: [
          expand: true
          flatten: true
          src: [
            'node_modules/codemirror/mode/markdown/markdown.js'
            'node_modules/codemirror/mode/gfm/gfm.js'
            'node_modules/codemirror/mode/xml/xml.js'
            'node_modules/codemirror/mode/meta.js'
            'node_modules/codemirror/mode/stex/stex.js'
            'node_modules/codemirror/keymap/vim.js'
            'node_modules/codemirror/keymap/emacs.js'
            'node_modules/codemirror/addon/dialog/dialog.js'
            'node_modules/codemirror/addon/edit/matchbrackets.js'
            'node_modules/codemirror/addon/edit/continuelist.js'
            'node_modules/codemirror/addon/fold/foldcode.js'
            'node_modules/codemirror/addon/fold/foldgutter.js'
            'node_modules/codemirror/addon/fold/markdown-fold.js'
            'node_modules/codemirror/addon/fold/xml-fold.js'
            'node_modules/codemirror/addon/mode/overlay.js'
            'node_modules/codemirror/addon/search/searchcursor.js'
            'node_modules/codemirror/addon/search/search.js'
            'node_modules/codemirror/addon/search/jump-to-line.js' # alt-G
            'node_modules/codemirror/addon/selection/active-line.js'
          ]
          dest: 'client/codemirror/'
        ]
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-replace'
  grunt.registerTask 'default', [
    'copy'
    'replace'
  ]

  ## Convert timezones into autocompletion list
  fs = require 'fs'
  meta = JSON.parse fs.readFileSync 'node_modules/moment-timezone/data/meta/latest.json', encoding: 'utf8'
  zones = JSON.parse fs.readFileSync 'node_modules/moment-timezone/data/unpacked/latest.json', encoding: 'utf8'
  timezones =
    for zone in zones.zones
      name = zone.name
      if name of meta.zones
        countries = meta.zones[name].countries
        countries = (meta.countries[country].name for country in countries)
        name += " (#{countries.join ', '})"
      name
  fs.writeFileSync 'public/timezones.json', JSON.stringify timezones
