Promise = require 'bluebird'
gulp = require 'gulp'
watch = require 'gulp-watch'
foreach = require 'gulp-foreach'
require 'colors'

#storage for tasks
_tasks = {}
#scope gulp
_gulp = null

#check if object is a promise via ducktyping
isPromise = (input)-> input && typeof input.then == 'function'
#check if object is a promise via ducktyping
isStream = (input)-> input && typeof input.pipe == 'function'

#helper function for humanizing the result of process.hrtime()
humanizeTime = (timeArray)->
	f=(n)->Math.floor(n)%1000;
	[s,m] = timeArray
	#generate time array
	suffix = [' s', ' ms', ' μs', ' ns']
	time = s+(m/1000000000)
	limit = 1
	ndx = 0
	while time < limit
		time *= 1000
		ndx++
	numDecimals = Math.max(0, 4-(parseInt(time)+'').length)
	time.toFixed(numDecimals)+suffix[ndx]

#creates a promise that resolves when a stream has ended
streamToPromise = (stream)-> new Promise (resolve, reject)->
	stream.on 'error', reject
	for success in ['drain', 'finish', 'end', 'close',]
		stream.on success, resolve

#the main task registration method
_task = (name, cb)->
	if _tasks[name]?
		end = _task.stackLength + 1
		newRegStack = new Error().stack.split('\n')[2..end].join('\n')
		oldRegStack = _tasks[name].registrationStack.split('\n')[2..end].join('\n')
		console.error "The 1st registration was at:\n".yellow.bold+oldRegStack.green
		console.error "The 2nd registration was at:\n".yellow.bold+newRegStack.green
		console.error "For longer stack traces, add 'task.stackLength = <number>' before declaring tasks.".gray
		console.error "Error: Task ".red+name.green+" has been declared twice.".red
		process.exit(1)
	_tasks[name] =
		callback:cb
		registrationStack:new Error().stack
	if _gulp?
		_gulp.task name, -> _task.run(name)

#execute task and promisify the return value
executeTask = (task)->
		returnVal = task.apply(null)
		if isPromise returnVal
			promise = returnVal
		else if isStream returnVal
			promise = streamToPromise returnVal
		else
			promise = Promise.resolve returnVal
		promise

#console.log tag
tag = "[#{"task".yellow}]"

#execute a previously registered task
_task.run = (name)->
	if typeof name == "string"
		#lookup registered task
		task = _tasks[name]?.callback
		if !task?
			throw new Error "Task Not Found: '#{name}'"
	#anonymous function support
	else if typeof name == "function"
		task = name
		name = null
	else
		console.error 'Unexpected parameter'.red
		end = _task.stackLength + 1
		console.error new Error().stack.split('\n')[2..end].join('\n').green
		throw new Error 'task.run expects either the name of a task registered with task or an anonymous function'

	startTime = process.hrtime()
	console.log "#{tag} Running '#{name.green.bold}'" if name #no error reporting for anonymous tasks

	return executeTask task
	.tap ->
		if name #no error reporting for anonymous functions
			timeDiff = process.hrtime(startTime)
			timeTaken = humanizeTime timeDiff
			console.log "#{tag} Finished '#{name.magenta.bold}' in "+timeTaken.green.bold
	.catch (error)->
		if name #no error reporting for anonymous functions
			if error.reported
				console.log "#{tag} "+"Failed to complete '".red + name.red.bold + "'".red
			else
				console.log "#{tag} "+"Failed to complete '".red + name.red.bold + "': #{error.message}".red
				console.log error.stack
				error.reported = true
		Promise.reject error


#configure gulp to automatically register tasks as gulp tasks
_task.configure = (gulp)->
	#if there are pre-existing tasks, and configure hasn't been called yet, when configure is called, register them
	if !_gulp?
		for name, task of _tasks
			_gulp.task name, -> _task.run(name)

	_gulp = gulp

_task.watch = (glob, cb)->
	ready = Promise.resolve()
	watch(glob).pipe foreach (stream, file)->
		ready = ready.then -> cb(stream, file, file.event)
		stream

_task.getTaskNames = -> Object.keys(_tasks).sort()

_task.stackLength = 1

_task.toString = -> 'gulp-task'

module.exports = _task
