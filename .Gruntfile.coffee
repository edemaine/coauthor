module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    copy:
      fonts:
        expand: true
        cwd: 'node_modules/katex/dist/fonts/'
        src: '**'
        dest: 'public/fonts/'
      codemirror:
        expand: true
        flatten: true
        src: [
          'node_modules/codemirror/theme/blackboard.css'
          'node_modules/codemirror/theme/eclipse.css'
        ]
        dest: 'client/codemirror/'
    replace:
      katex:
        options:
          patterns: [
            match: /url\(fonts/g
            replacement: 'url(/fonts'
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
            replacement: 'require("meteor/mizzao:sharejs-codemirror/node_modules/codemirror/lib/codemirror.js")'
          ,
            match: /require\("[^"]*\//g
            replacement: 'require("./'
          #  match: /\(function[^]*?function\(CodeMirror\) {/
          #  replacement: 'const CodeMirror = require("meteor/mizzao:sharejs-codemirror/node_modules/codemirror/lib/codemirror.js");'
          #,
          #  match: /}\);\s*$/
          #  replacement: ''
          ]
        files: [
          expand: true
          flatten: true
          src: [
            'node_modules/codemirror/mode/markdown/markdown.js'
            'node_modules/codemirror/mode/gfm/gfm.js'
            'node_modules/codemirror/addon/mode/overlay.js'
            'node_modules/codemirror/mode/xml/xml.js'
            'node_modules/codemirror/mode/meta.js'
            'node_modules/codemirror/mode/stex/stex.js'
            'node_modules/codemirror/addon/selection/active-line.js'
            'node_modules/codemirror/addon/edit/matchbrackets.js'
          ]
          dest: 'client/codemirror/'
        ]
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-replace'
  grunt.registerTask 'default', [
    'copy'
    'replace'
  ]
