'use strict';
module.exports = function (grunt) {
  // load all grunt tasks
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks);
  var serveStatic = require('serve-static');
  var path = require('path');
  var mountFolder = function (connect, dir) {
    return serveStatic(path.resolve(dir));
  };
  // configurable paths
  var yeomanConfig = {
    name: 'reactive-coffee',
    src: 'src',
    dist: 'dist'
  };

  try {
    yeomanConfig.src = require('./component.json').appPath || yeomanConfig.src;
  } catch (e) {}

  grunt.initConfig({
    yeoman: yeomanConfig,
    watch: {
      livereload: {
        files: [
          '<%= yeoman.src %>/{,*/}*.html',
          '{.tmp,<%= yeoman.src %>}/styles/{,*/}*.css',
          '{.tmp,<%= yeoman.src %>}/{,*/}*.js',
          '<%= yeoman.src %>/images/{,*/}*.{png,jpg,jpeg,gif,webp,svg}'
        ],
        tasks: ['livereload']
      }
    },
    bower: {
      install: {}
    },
    connect: {
      options: {
        port: 9000,
        // Change this to '0.0.0.0' to access the server from outside.
        hostname: 'localhost'
      },
      test: {
        options: {
          middleware: function (connect) {
            return [
              mountFolder(connect, '.tmp'),
              mountFolder(connect, 'test')
            ];
          }
        }
      }
    },
    coffee: {
      dist: {
        options: {
          sourceMap: true
        },
        files: [{
          expand: true,
          cwd: '<%= yeoman.src %>',
          src: '{,*/}*.coffee',
          dest: '.tmp',
          ext: '.js'
        }]
      }
    },
    clean: {
      dist: {
        files: [{
          dot: true,
          src: [
            '.tmp',
            '<%= yeoman.dist %>/*',
            '!<%= yeoman.dist %>/.git*'
          ]
        }]
      },
      server: '.tmp'
    },
    karma: {
      unit: {configFile: 'karma.conf.js'}
    },
    concat: {
      dist: {
        files: {
          '<%= yeoman.dist %>/<%= yeoman.name %>.js': [
            '.tmp/{,*/}*.js',
            '<%= yeoman.src %>/{,*/}*.js'
          ]
        }
      }
    },
    copy: {
      maps: {
        src: '.tmp/reactive.js.map',
        dest: 'dist/reactive.js.map'
      }
    },
    uglify: {
      dist: {
        options: {
          sourceMap: true,
          sourceMapIn: 'dist/reactive.js.map',
          sourceMapName: 'dist/reactive-coffee.min.js.map'
        },
        files: {
          '<%= yeoman.dist %>/<%= yeoman.name %>.min.js': [
            '<%= yeoman.dist %>/<%= yeoman.name %>.js'
          ]
        }
      }
    },
    ts: {
      options: {
        compile: true,         // perform compilation. [true (default) | false]
        comments: false,       // same as !removeComments. [true | false (default)]
        target: 'es5',         // target javascript language. [es3 | es5 (grunt-ts default) | es6]
        noImplicitAny: false,  // set to true to pass --noImplicitAny to the compiler. [true | false (default)]
        strictNullChecks: true,
        alwaysStrict: false
      },
      dev: {
        src: ["src/**/*.ts"],  // The source typescript files, http://gruntjs.com/configuring-tasks#files
        options: {
          module: 'commonjs'
        }
      }
    }
  });

  grunt.renameTask('regarde', 'watch');

  grunt.registerTask('test', [
    'clean:server',
    'ts:dev',
    'coffee',
    // 'bower:install', // slows down build a bit and puts things in ./lib
    'connect:test',
    'karma'
  ]);

  grunt.registerTask('build', [
    'clean:dist',
    'test',
    'concat',
    'copy',
    'uglify'
  ]);

  grunt.registerTask('default', ['build']);
};
