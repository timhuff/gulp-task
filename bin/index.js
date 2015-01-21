(function() {
  var Promise, executeTask, humanizeTime, isPromise, isStream, streamToPromise, tag, _gulp, _task, _tasks;

  Promise = require('bluebird');

  require('colors');

  _tasks = {};

  _gulp = null;

  isPromise = function(input) {
    return input && typeof input.then === 'function';
  };

  isStream = function(input) {
    return input && typeof input.pipe === 'function';
  };

  humanizeTime = function(timeArray) {
    var f, limit, m, ndx, numDecimals, s, suffix, time;
    f = function(n) {
      return Math.floor(n) % 1000;
    };
    s = timeArray[0], m = timeArray[1];
    suffix = [' s', ' ms', ' μs', ' ns'];
    time = s + (m / 1000000000);
    limit = 1;
    ndx = 0;
    while (time < limit) {
      time *= 1000;
      ndx++;
    }
    numDecimals = Math.max(0, 4 - (parseInt(time) + '').length);
    return time.toFixed(numDecimals) + suffix[ndx];
  };

  streamToPromise = function(stream) {
    return new Promise(function(resolve, reject) {
      var success, _i, _len, _ref, _results;
      stream.on('error', reject);
      _ref = ['drain', 'finish', 'end', 'close'];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        success = _ref[_i];
        _results.push(stream.on(success, resolve));
      }
      return _results;
    });
  };

  _task = function(name, cb) {
    var end, newRegStack, oldRegStack;
    if (_tasks[name] != null) {
      end = _task.debug ? Infinity : 3;
      newRegStack = new Error().stack.split('\n').slice(2, +end + 1 || 9e9).join('\n');
      oldRegStack = _tasks[name].registrationStack.split('\n').slice(2, +end + 1 || 9e9).join('\n');
      console.error("The 1st registration was at:\n".yellow.bold + oldRegStack.green);
      console.error("The 2nd registration was at:\n".yellow.bold + newRegStack.green);
      console.error("Error: Task ".red + name.green + " has been declared twice.".red);
      console.error('For full stack traces, add ' + 'task.debug = true' + ' before declaring tasks.'.gray);
      process.exit(1);
      return;
    }
    _tasks[name] = {
      callback: cb,
      registrationStack: new Error().stack
    };
    if (_gulp != null) {
      return _gulp.task(name, function() {
        return _task.run(name);
      });
    }
  };

  executeTask = function(task) {
    var promise, returnVal;
    returnVal = task.apply(null);
    if (isPromise(returnVal)) {
      promise = returnVal;
    } else if (isStream(returnVal)) {
      promise = streamToPromise(returnVal);
    } else {
      promise = Promise.resolve(returnVal);
    }
    return promise;
  };

  tag = "[" + "task".yellow + "]";

  _task.run = function(name) {
    var startTime, task;
    if (typeof name === "string") {
      task = _tasks[name].callback;
      if (task == null) {
        throw new Error("Task Not Found: '" + name + "'");
      }
    } else if (typeof name === "function") {
      task = name;
      name = null;
    } else {
      throw new Error('task.run expects either the name of a task registered with task or an anonymous function');
    }
    startTime = process.hrtime();
    if (name) {
      console.log("" + tag + " Running '" + name.green.bold + "'");
    }
    return executeTask(task).tap(function() {
      var timeDiff, timeTaken;
      if (name) {
        timeDiff = process.hrtime(startTime);
        timeTaken = humanizeTime(timeDiff);
        return console.log(("" + tag + " Finished '" + name.magenta.bold + "' in ") + timeTaken.green.bold);
      }
    })["catch"](function(error) {
      if (name) {
        if (error.reported) {
          console.log(("" + tag + " ") + "Failed to complete '".red + name.red.bold + "'".red);
        } else {
          console.log(("" + tag + " ") + "Failed to complete '".red + name.red.bold + ("': " + error.message).red);
          console.log(error.stack);
          error.reported = true;
        }
      }
      return Promise.reject(error);
    });
  };

  _task.configure = function(gulp) {
    var name, task;
    if (_gulp == null) {
      for (name in _tasks) {
        task = _tasks[name];
        _gulp.task(name, function() {
          return _task.run(name);
        });
      }
    }
    return _gulp = gulp;
  };

  _task.getTaskNames = function() {
    return Object.keys(_tasks).sort();
  };

  module.exports = _task;

}).call(this);
