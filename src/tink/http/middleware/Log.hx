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
		logger.log(HttpIn(req.header.method, req.header.uri));
		var res = handler.process(req);
		res.handle(function(res) logger.log(HttpOut(res.header.statusCode, req.header.method, req.header.uri)));
		return res;
	}
}

enum LogMessage {
	HttpIn(method:Method, uri:String);
	HttpOut(code:Int, method:Method, uri:String);
}

class LogMessageFormatter {
	public static function format(message:LogMessage) {
		var buf = new StringBuf();
		inline function addSegment(s:String) {
			buf.add(s);
			buf.add(' | ');
		}
		
		addSegment(Date.now().toString());
		
		switch message {
			case HttpIn(method, uri):
				addSegment('IN'.rpad(' ', 8));
				addSegment((method:String).rpad(' ', 8));
				buf.add(uri);
			case HttpOut(code, method, uri):
				addSegment('OUT $code'.rpad(' ', 8));
				addSegment((method:String).rpad(' ', 8));
				buf.add(uri);
		}
		return buf.toString();
	}
}

interface Logger {
	function log(message:LogMessage):Void;
}

class DefaultLogger implements Logger {
	public function new() {}
	
	public function log(message:LogMessage)
		Sys.println(LogMessageFormatter.format(message));
}
