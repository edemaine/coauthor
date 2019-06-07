module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    clean:
      codemirror:
        src: [
          'client/codemirror/*.js'
        ]
      css:
        src: [
          'client/*.min.css'
        ]
    less:
      options: ## Based on node_modules/bootstrap/Gruntfile.js
        ieCompat: true
        strictMath: true
      light:
        src: 'node_modules/bootstrap/less/bootstrap.less'
        dest: '.bootstrap/light.css'
        options:
          modifyVars:
            'blockquote-font-size': '@font-size-base' # usually * 1.25
      dark:
        ## Colors based in part on Cyborg theme distributed under MIT License:
        ## https://github.com/thomaspark/bootswatch/blob/v3/cyborg/variables.less
        options:
          modifyVars:
            'blockquote-font-size': '@font-size-base' # usually * 1.25
            #'brand-primary': '#2A9FD6'
            #'brand-success': '#77B300'
            #'brand-info':    '#9933CC'
            #'brand-warning': '#FF8800'
            #'brand-danger':  '#CC0000'
            'body-bg':       '#060606'
            'link-color':    'lighten(@brand-primary, 25%)'
            'text-color':    '@gray-lighter'
            'panel-bg':                 '@body-bg'
            'panel-inner-border':       '@gray-dark'
            'panel-footer-bg':          'lighten(@gray-darker, 10%)'
            'panel-default-text':       '@text-color'
            'panel-default-border':     '@panel-inner-border'
            'panel-default-heading-bg': '@panel-footer-bg'
            'btn-default-color':  '@text-color'
            'btn-default-bg':     'lighten(@gray-dark, 10%)'
            'btn-default-border': 'darken(@btn-default-bg, 5%)'
            'btn-info-color':     '#000'
            'btn-success-color':  '#000'
            'btn-warning-color':  '#000'
            'link-hover-color':   'lighten(@link-color, 15%);' # usually darken
            'tooltip-bg':         '@gray-darker'
            'navbar-default-color':               '@text-color'
            'navbar-default-bg':                  '@gray-darker'
            'navbar-default-link-color':          '@text-color'
            'navbar-default-link-hover-color':    '#fff'
            'navbar-default-link-active-color':   '#fff'
            'navbar-default-link-active-bg':      'transparent'
            'navbar-default-link-disabled-color': '@gray-light'
            'navbar-default-brand-color':         '#fff'
            'navbar-default-brand-hover-color':   '#fff'
            'navbar-default-toggle-hover-bg':     '@gray-dark'
            'navbar-default-toggle-icon-bar-bg':  '#ccc'
            'navbar-default-toggle-border-color': '@gray-dark'
            'nav-link-hover-bg':                       '@gray-darker'
            'nav-tabs-border-color':                   '@gray-dark'
            'nav-tabs-link-hover-border-color':        'transparent'
            'nav-tabs-active-link-hover-bg':           '@brand-primary'
            'nav-tabs-active-link-hover-color':        '#fff'
            'nav-tabs-active-link-hover-border-color': '@gray-dark'
            'pre-bg':                     '@gray-darker'
            'pre-color':                  '@gray-lighter'
            'pre-border-color':           '@gray-dark'
            'dropdown-bg':                '@gray-darker'
            'dropdown-border':            'rgba(255,255,255,0.1)'
            'dropdown-fallback-border':   '#444'
            'dropdown-divider-bg':        'rgba(255,255,255,0.1)'
            'dropdown-link-color':        '#fff'
            'dropdown-link-hover-color':  'darken(@dropdown-link-color, 0%)'
            'dropdown-link-hover-bg':     '@gray'
            'table-bg':                   'darken(@gray-darker, 4%)'
            'table-bg-accent':            'darken(@table-bg, 6%)'
            'table-bg-hover':             '@gray-dark'
            'table-border-color':         '@gray-dark'
            'state-success-text':         '#fff'
            'state-success-bg':           'darken(@brand-success, 35%)'
            'state-info-text':            '#fff'
            'state-info-bg':              'darken(@brand-info, 45%)'
            'state-warning-text':         '#fff'
            'state-warning-bg':           'darken(@brand-warning, 45%)'
            'state-danger-text':          '#fff'
            'state-danger-bg':            'darken(@brand-danger, 35%)'
            'modal-content-bg':           'lighten(@body-bg, 10%)'
            'modal-header-border-color':  '@gray-dark'
            'input-bg':                   '@gray-darker'
            'input-color':                '@text-color'
            'input-border':               '@gray-dark'
            'input-color-placeholder':    '@gray-light'
            'input-bg-disabled':          '@gray-dark'
            'legend-color':               '@text-color'
            'legend-border-color':        '@gray-dark'
            'progress-bg':                '@gray-darker'
            'list-group-bg':                 '@gray-darker'
            'list-group-border':             '@gray-dark'
            'list-group-hover-bg':           'lighten(@list-group-bg, 15%)'
            'list-group-link-color':         '@text-color'
            'list-group-link-heading-color': '#fff'
            'label-color':            '#000'
            'label-link-hover-color': '#000'
            'blockquote-border-color': '@gray-dark'
        src: 'node_modules/bootstrap/less/bootstrap.less'
        dest: '.bootstrap/dark.css'
    copy:
      katex_fonts:
        expand: true
        cwd: 'node_modules/katex/dist/fonts/'
        src: '**'
        dest: 'public/katex/fonts/'
      codemirrorCSS:
        expand: true
        flatten: true
        src: [
          'node_modules/codemirror/theme/blackboard.css'
          #'node_modules/codemirror/theme/eclipse.css'
          'node_modules/codemirror/addon/dialog/dialog.css'
          'node_modules/codemirror/addon/fold/foldgutter.css'
          'node_modules/codemirror/addon/hint/show-hint.css'
        ]
        dest: 'client/codemirror/'
      pdfjs:
        expand: true
        flatten: true
        src: 'node_modules/pdfjs-dist/build/pdf.worker.min.js'
        dest: 'public/'
      bootstrap:
        expand: true
        flatten: true
        src: [
          'node_modules/bootstrap/dist/js/bootstrap.min.js'
        ]
        dest: 'client/bootstrap/'
      bootstrap_slider:
        expand: true
        flatten: true
        src: 'node_modules/bootstrap-slider/dist/css/bootstrap-slider.min.css'
        dest: 'client/bootstrap/'
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
      codemirrorCSS:
        options:
          patterns: [
            ## This rule causes enumerated lists in Markdown to get
            ## highlighted, overriding math highlighting for example.
            match: /\.cm[-a-z]* span\.cm-variable-[23].*/g
            replacement: ''
          ]
        files: [
          expand: true
          flatten: true
          src: 'node_modules/codemirror/theme/eclipse.css'
          dest: 'client/codemirror/'
        ]
      codemirror:
        options:
          patterns: [
            match: /require\("codemirror\/lib\/codemirror"\)/
            replacement: 'require("codemirror")'
          ,
            match: /require\("..\//g
            replacement: 'require("codemirror/mode/'
          ,
            match: /require\("..\/..\//g
            replacement: 'require("codemirror/'
          #  match: /\(function[^]*?function\(CodeMirror\) {/
          #  replacement: 'const CodeMirror = require("meteor/edemaine:sharejs-codemirror/node_modules/codemirror/lib/codemirror.js");'
          #,
          #  match: /}\);\s*$/
          #  replacement: ''
          ,
            match: /\|coap\|/
            replacement: '|coap|coauthor|'
          ,
            match: /newlineAndIndentContinueMarkdownList/
            replacement: 'xnewlineAndIndentContinueMarkdownList'
          ,
            match: /cm\.getMode\(\)\.innerMode\(/
            replacement: 'CodeMirror.innerMode(cm.getMode(), '
          ]
        files: [
          expand: true
          flatten: true
          src: [
            'node_modules/codemirror/addon/hint/show-hint.js'
            #'node_modules/codemirror/mode/markdown/markdown.js'
            'node_modules/codemirror/mode/gfm/gfm.js'
            #'node_modules/codemirror/mode/xml/xml.js'
            #'node_modules/codemirror/mode/meta.js'
            #'node_modules/codemirror/mode/stex/stex.js'
            #'node_modules/codemirror/keymap/vim.js'
            #'node_modules/codemirror/keymap/emacs.js'
            #'node_modules/codemirror/addon/dialog/dialog.js'
            #'node_modules/codemirror/addon/edit/matchbrackets.js'
            'node_modules/codemirror/addon/edit/continuelist.js'
            #'node_modules/codemirror/addon/fold/foldcode.js'
            #'node_modules/codemirror/addon/fold/foldgutter.js'
            #'node_modules/codemirror/addon/fold/markdown-fold.js'
            #'node_modules/codemirror/addon/fold/xml-fold.js'
            #'node_modules/codemirror/addon/mode/overlay.js'
            #'node_modules/codemirror/addon/search/searchcursor.js'
            #'node_modules/codemirror/addon/search/search.js'
            #'node_modules/codemirror/addon/search/jump-to-line.js' # alt-G
            #'node_modules/codemirror/addon/selection/active-line.js'
          ]
          dest: 'client/codemirror/'
        ]
      bootstrap:
        options:
          patterns: [
            match: /@font-face\s*{\s*font-family:\s*"Glyphicons[^]*?\*/
            replacement: '*'
          ]
        files: [
          expand: true
          flatten: true
          src: [
            '.bootstrap/dark.css'
            '.bootstrap/light.css'
          ]
          dest: '.bootstrap/noglyphicon'
        ]
    cssmin:
      options: ## Based on node_modules/bootstrap/Gruntfile.js
        compatibility: 'ie8'
        level:
          1:
            specialComments: 'all'
      light:
        src: '.bootstrap/noglyphicon/light.css'
        dest: 'public/bootstrap/light.min.css'
      dark:
        src: '.bootstrap/noglyphicon/dark.css'
        dest: 'public/bootstrap/dark.min.css'

  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-replace'
  grunt.loadNpmTasks 'grunt-contrib-less'
  grunt.loadNpmTasks 'grunt-contrib-cssmin'
  grunt.registerTask 'default', [
    'clean'
    'less'
    'copy'
    'replace'
    'cssmin'
  ]

  ## Convert timezones into autocompletion list
  fs = require 'fs'
  meta = JSON.parse fs.readFileSync 'node_modules/moment-timezone/data/meta/latest.json', encoding: 'utf8'
  zones = JSON.parse fs.readFileSync 'node_modules/moment-timezone/data/packed/latest.json', encoding: 'utf8'
  timezones =
    for zone in zones.zones
      #name = zone.name  ## unpacked format
      name = zone
      name = name[...name.indexOf '|'] if '|' in name  ## packed format
      if name of meta.zones
        countries = meta.zones[name].countries
        countries = (meta.countries[country].name for country in countries)
        name += " (#{countries.join ', '})"
      name
  fs.writeFileSync 'public/timezones.json', JSON.stringify timezones
