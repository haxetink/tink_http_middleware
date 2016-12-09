package tink.http.middleware;

import tink.http.Request;
import tink.http.Response;
import tink.http.Middleware;
import tink.http.Handler;
import tink.http.Method;

using StringTools;
using tink.CoreApi;

class Log implements MiddlewareObject {
	var logger:Logger;
	
	public function new(?logger) {
		this.logger = if(logger == null) new DefaultLogger() else logger;
	}
	
	public function apply(handler:Handler):Handler
		return new LogHandler(logger, handler);
}

class LogHandler implements HandlerObject {
	var logger:Logger;
	var handler:Handler;
	
	public function new(logger, handler) {
		this.logger = logger;
		this.handler = handler;
	}
	
	public function process(req:IncomingRequest) {
		logger.log(HttpIn(req));
		var res = handler.process(req);
		res.handle(function(res) logger.log(HttpOut(req, res)));
		return res;
	}
}

enum LogMessage {
	HttpIn(req:IncomingRequest);
	HttpOut(req:IncomingRequest, res:OutgoingResponse);
}

class LogMessageFormatter {
	public static function format(message:LogMessage, verbose:Bool) {
		var buf = new StringBuf();
		inline function addSegment(s:String) {
			buf.add(s);
			buf.add(' | ');
		}
		
		addSegment(Date.now().toString());
		
		switch message {
			case HttpIn(req):
				addSegment('IN'.rpad(' ', 8));
				addSegment((req.header.method:String).rpad(' ', 8));
				buf.add(req.header.uri);
				if(verbose) {
					for(header in req.header.fields) buf.add('\n  ' + header.name + ': ' + header.value);
				}
			case HttpOut(req, res):
				addSegment('OUT ${res.header.statusCode}'.rpad(' ', 8));
				addSegment((req.header.method:String).rpad(' ', 8));
				buf.add(req.header.uri);
				if(verbose) {
					for(header in res.header.fields) buf.add('\n  ' + header.name + ': ' + header.value);
				}
		}
		return buf.toString();
	}
}

interface Logger {
	function log(message:LogMessage):Void;
}

class DefaultLogger implements Logger {
	var verbose:Bool;
	public function new(verbose = false) {
		this.verbose = verbose;
	}
	
	public function log(message:LogMessage)
		Sys.println(LogMessageFormatter.format(message, verbose));
}
