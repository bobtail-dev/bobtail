// Karma configuration

module.exports = function(config) {
  let configuration = {
    basePath: "",
    frameworks: ["jasmine", "browserify"],
    // list of files / patterns to load in the browser
    files: [
      'src/**/*.js',
      'test/**/*'
    ],

    preprocessors: {
        'src/**/*': ['browserify'],
        'test/**/*': ['browserify']
    },

    browserify: {
        debug: true,
        transform: ['babelify'],
        extensions: ['js', 'jsx']
    },

    // test results reporter to use
    // possible values: dots || progress || growl
    reporters: ["progress"],

    // web server port
    port: 8080,

    // cli runner port
    runnerPort: 9100,

    // enable / disable colors in the output (reporters and logs)
    colors: true,

    // level of logging
    // possible values: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
    logLevel: config.LOG_INFO,

    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: false,
    browsers: ["Chrome"],
    plugins: ["karma-chrome-launcher", "karma-jasmine", "karma-browserify"],
    customLaunchers: {
      Chrome_travis_ci: {
        base: "Chrome",
        flags: ["--no-sandbox"]
      },
      // Chrome configuration for Bash for Windows.
      // Developers using Bash for Windows must configure the following env variables:
      // CHROME_BIN: should point to your chrome.exe folder, using BfW's /mnt/<drive>
      // style notation.
      Chrome_bfw: {
        base: "Chrome",
        chromeDataDir: ".bobtail-karma-chrome-data"
        // necessary because otherwise Karma will attempt to use the /tmp directory, which apparently
        // the Chrome executable spawned by karma does not have the right permissions for. As a result
        // Chrome throws up an annoying blocking modal, which has to be closed before tests can continue.
        // This avoids that problem.
      }
    },

    // If browser does not capture in given timeout [ms], kill it
    captureTimeout: 10000,

    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: true
  };

  if (process && process.env && process.env.TRAVIS) {
    configuration.browsers = ["Chrome_travis_ci"];
  } else if (process.env.BOBTAIL_KARMA_BFW) {
    configuration.browsers = ["Chrome_bfw"];
  }

  config.set(configuration);
};
