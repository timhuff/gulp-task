
# gulp-task

# Basic Info
## Preface

This module is currently under heavy development. If you include it in your project, lock down the version number.

This was written as a wrapper for gulp.task in order to get promise-based dependency management.

The documentation and source is written in coffeescript but it should work with vanilla gulp just the same.

Unfortunately, I don't have time to write tests at the moment.

## Installation
```shell
npm install --save gulp-task
```
```coffee
task = require 'gulp-task'
```
Optionally, you can configure it to automatically register gulp tasks:
```coffee
task.configure gulp
```
## API
This module has 4 functions. Here is the order that you'll most likely use them:
- `task.configure`
- `task`
- `task.run`
- `task.watch`
- `task.getTaskNames`

### task.configure(gulp)
This makes it so that when you run task(name, cb), you also register the same task with gulp, enabling command line execution.
### task(name, cb)
This registers a new task to later be run via task.run. Dependencies are taken care of via promises.
### task.run(name|cb)
This accepts either the name of a previously registered task or an anonymous function.
### task.getTaskNames()
This simply returns a sorted list the names of registered tasks.

# Notes

## A Note About Not Running `task.configure`
This module was written as a replacement for `gulp.task`. You're still free to use gulp.task directly but those tasks registered via `gulp.task` will not be visible via `task.run`. A usage where you don't run `task.configure gulp` might looks something like:
```
gulp.task 'build', ->
	task.run 'compile'
	.then -> task.run 'copy'
task 'compile', -> #compile code
task 'copy', -> #copy code
```
In this case, you'd be able to run `coffeegulp build` from command-line but not `coffeegulp compile` or `coffeegulp copy`.  
This "private task" effect is why configuring was made optional.

## A Note About Tasks
`task.run` returns a `Promise`. How that promise is resolved depends on the return value of the function being run.

Regardless of if you're running an anonymous function or calling a registered one by name, the nature of the returned promise falls into three cases.
### Case 1: Task Returns a Promise
This is simple enough. `task.run` simply returns the promise.
### Case 2: Task Returns a Stream
`task.run` returns a promise that resolves via `.pipe gulpCallback -> resolve stream`
### Case 3: Task Returns Something Else
In this event, `task.run` simply returns a resolved promise after running the task.

## A Note About `.then -> gulp.src`
Let's say that you're defining a task that does some stuff via task.run and then calls `.then` on the promise and provides a callback which returns a `Stream`.

This would be an issue. The resolve chain would not wait for the gulp.src stream to end before continuing.  
This might result in unexpected concurrency and reporting issues.

It's important to wrap streams in a `task.run ->` when being called from within a `.then ->`.

###**Acceptable**
```coffee
task 'copy', ->
	gulp.src('src')
	.pipe gulp.dest 'dest'
```
```coffee
task 'build', ->
	task.run 'compile'
	.then -> task.run 'copy'
```
```coffee
task 'build', ->
	task.run 'compile'
	.then -> task.run ->
		gulp.src('src')
		.pipe gulp.dest 'dest'
```
```coffee
task 'build', ->
	task.run 'compile'
	.then ->
		somethingSynchronous()
```
```coffee
task 'watch', ->
  task.run 'compile'
  .then -># Warning: This is over-simplified and potentially problematic.
          # See "Watch Example" below for more info.
    gulp.watch ['src/**/*.coffee'], -> task.run 'compile'
```
###**Not Acceptable**
```coffee
task 'build', ->
	task.run 'compile'
	.then ->
		gulp.src('src')
		.pipe gulp.dest 'dest'
```

# Examples

---
## Semi-Realistic Stream Example
#### gulpfile.coffee
```coffee
task = require 'gulp-task'
gulp = require 'gulp'
coffee = require 'gulp-coffee'
jade = require 'gulp-jade'
rimraf = require 'gulp-rimraf'
Promise = require 'bluebird'
task.configure gulp

task 'refresh', ->
	task.run 'clean'
	.then -> task.run 'compile'

task 'clean', ->
	gulp.src 'bin', read: false
	.pipe rimraf()

task 'compile', ->
	Promise.all([
		task.run 'compile:coffee'
		task.run 'compile:jade'
	])

task 'compile:coffee', ->
  gulp.src "src/**/*.coffee"
  .pipe coffee()
  .pipe gulp.dest 'bin'

task 'compile:jade', ->
  gulp.src "src/**/*.jade"
  .pipe jade()
  .pipe gulp.dest 'bin'

```
#### Output
```console
$ coffeegulp rebuild
[gulp] Using gulpfile ~/Documents/GitProjects/gulp-task/gulpfile.coffee
[gulp] Starting 'rebuild'...
[task] Running 'rebuild'
[task] Running 'clean'
[task] Finished 'clean' in 11.546 ms
[task] Running 'compile'
[task] Running 'compile:coffee'
[task] Running 'compile:jade'
[task] Finished 'compile:coffee' in 56.239 ms
[task] Finished 'compile:jade' in 53.605 ms
[task] Finished 'compile' in 56.998 ms
[task] Finished 'rebuild' in 69.254 ms
[gulp] Finished 'rebuild' after 69 ms
```
---
### Hello World
#### gulpfile.coffee
```coffee
task = require 'gulp-task'
gulp = require 'gulp'
task.configure gulp

task 'default', ->
	task.run 'hello'

task 'hello', ->
	console.log 'Hello World!'
```
#### Output
```console
$ coffeegulp
[gulp] Using gulpfile ~/Documents/GitProjects/gulp-task/gulpfile.coffee
[gulp] Starting 'default'...
[task] Running 'default'
[task] Running 'hello'
Hello World!
[task] Finished 'hello' in 1.244 ms
[task] Finished 'default' in 1.728 ms
[gulp] Finished 'default' after 1.91 ms
```
---
### Basic Stream
#### gulpfile.coffee
```coffee
task = require 'gulp-task'
gulp = require 'gulp'
coffee = require 'gulp-coffee'
gulp = require 'gulp'
task.configure gulp

task 'compile', ->
  gulp.src "src/**/*.coffee"
  .pipe coffee()
  .pipe gulp.dest 'bin'
```
#### Output
```console
$ coffeegulp compile
[gulp] Using gulpfile ~/Documents/GitProjects/gulp-task/gulpfile.coffee
[gulp] Starting 'compile'...
[task] Running 'compile'
[task] Finished 'compile' in 22.872 ms
[gulp] Finished 'compile' after 23 ms
```
---
### Basic `task.watch`
#### gulpfile.coffee
```coffee
task = require 'gulp-task'
gulp = require 'gulp'
coffee = require 'gulp-coffee'
gulp = require 'gulp'
task.configure gulp

task 'compile', ->
  gulp.src "src/**/*.coffee"
  .pipe coffee()
  .pipe gulp.dest 'bin'

task 'watch', ->
  task.run 'compile'
  .then ->
    task.watch ['src/**/*.coffee'], -> task.run 'compile'
```
#### Output
```console
$ coffeegulp watch
[gulp] Using gulpfile ~/Documents/GitProjects/gulp-task/gulpfile.coffee
[gulp] Starting 'watch'...
[task] Running 'watch'
[task] Running 'compile'
[task] Finished 'compile' in 14.42 ms
[task] Finished 'watch' in 20.66 ms
[gulp] Finished 'watch' after 21 ms
<MADE CHANGE>
[task] Running 'compile'
[task] Finished 'compile' in 3.800 ms
```
---
### Running Tasks in Series / Using Promises
#### gulpfile.coffee
```coffee
task = require 'gulp-task'
gulp = require 'gulp'
task.configure gulp
Promise = require 'bluebird'

task 'series', ->
	task.run 'a'
	.then -> task.run 'b'
	.then ->
		console.log 'We Are Done'

task 'a', -> new Promise (resolve, reject)->
	setTimeout ->
		console.log 'Task A!'
		resolve()
	, 1500

task 'b', -> new Promise (resolve, reject)->
	setTimeout ->
		console.log 'Task B!'
		resolve()
	, 2000
```
#### Output
```console
$ coffeegulp series
[gulp] Using gulpfile ~/Documents/GitProjects/gulp-task/gulpfile.coffee
[gulp] Starting 'series'...
[task] Running 'series'
[task] Running 'a'
Task A!
[task] Finished 'a' in 1.502 s
[task] Running 'b'
Task B!
[task] Finished 'b' in 2.001 s
We Are Done
[task] Finished 'series' in 3.504 s
[gulp] Finished 'series' after 3.5 s
```
### Running Tasks in Parallel / Using Promises
#### gulpfile.coffee
```coffee
task = require 'gulp-task'
gulp = require 'gulp'
task.configure gulp
Promise = require 'bluebird'

task 'parallel', ->
	Promise.all([
		task.run 'a'
		task.run 'b'
	]).then ->
		console.log 'We Are Done'

task 'a', -> new Promise (resolve, reject)->
	setTimeout ->
		console.log 'Task A!'
		resolve()
	, 1500

task 'b', -> new Promise (resolve, reject)->
	setTimeout ->
		console.log 'Task B!'
		resolve()
	, 2000
```
#### Output
```console
$ coffeegulp parallel
[gulp] Using gulpfile ~/Documents/GitProjects/gulp-task/gulpfile.coffee
[gulp] Starting 'parallel'...
[task] Running 'parallel'
[task] Running 'a'
[task] Running 'b'
Task A!
[task] Finished 'a' in 1.502 s
Task B!
[task] Finished 'b' in 2.002 s
We Are Done
[task] Finished 'parallel' in 2.003 s
[gulp] Finished 'parallel' after 2 s
```
