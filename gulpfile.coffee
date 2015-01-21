gulp = require 'gulp'
task = require './index'
task.configure gulp

coffee = require 'gulp-coffee'

gulp.task 'default', ->task.run 'build'

task 'build', ->
	gulp.src 'index.coffee'
	.pipe coffee()
	.pipe gulp.dest 'bin'

task 'watch', ->
	task.run 'build'
	.then -> 
		gulp.watch 'index.coffee', -> task.run 'build'
