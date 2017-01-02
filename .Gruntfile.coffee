module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    copy:
      fonts:
        expand: true
        cwd: 'node_modules/katex/dist/fonts/'
        src: '**'
        dest: 'public/fonts/'
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
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-replace'
  grunt.registerTask 'default', [
    'copy'
    'replace'
  ]
