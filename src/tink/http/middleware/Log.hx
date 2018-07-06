package tink.http.middleware;

import tink.http.Request;
import tink.http.Response;
import tink.http.Middleware;
import tink.http.Handler;
import tink.http.Method;

using StringTools;
using tink.CoreApi;
using tink.io.Source;

class Log implements MiddlewareObject {
	var logger:Logger;
	var skip:Array<EReg>;
	
	public function new(?logger, ?skip) {
		this.logger = if(logger == null) new DefaultLogger() else logger;
		this.skip = skip == null ? [] : skip;
	}
	
	public function apply(handler:Handler):Handler
		return new LogHandler(logger, skip, handler);
}

class LogHandler implements HandlerObject {
	var logger:Logger;
	var skip:Array<EReg>;
	var handler:Handler;
	
	public function new(logger, skip, handler) {
		this.logger = logger;
		this.skip = skip;
		this.handler = handler;
	}
	
	public function process(req:IncomingRequest) {
		// skip logger if matched uri prefix
		var uri = req.header.url.path.toString();
		for(s in skip) if(s.match(uri)) return handler.process(req);
		
		var key = haxe.crypto.Sha1.encode(Math.random() + '').substr(0, 8);
		var start = stamp();
		logger.log(HttpIn(key, req.header));
		var res = handler.process(req);
		res.handle(function(res) {
			logger.log(HttpOut(key, req.header, res, stamp() - start));
			if(res.header.statusCode.toInt() >= 400)
				res.body.all().handle(function(o) Sys.println(o.toString()));
		});
		return res;
	}
	
	static function stamp()
		return Std.int(haxe.Timer.stamp() * 1000);
}

enum LogMessage {
	HttpIn(key:String, req:IncomingRequestHeader);
	HttpOut(key:String, req:IncomingRequestHeader, res:OutgoingResponse, duration:Int);
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
			case HttpIn(key, req):
				addSegment(key);
				addSegment('IN'.rpad(' ', 8));
				addSegment((req.method:String).rpad(' ', 8));
				addSegment(''.rpad(' ', 8));
				buf.add(req.url.pathWithQuery);
				if(verbose) {
					var hasHeader = false;
					for(header in req) {
						hasHeader = true;
						buf.add('\n  ' + header.name + ': ' + header.value);
					}
					if(hasHeader) buf.add('\n');
				}
			case HttpOut(key, req, res, duration):
				addSegment(key);
				addSegment('OUT ${res.header.statusCode.toInt()}'.rpad(' ', 8));
				addSegment((req.method:String).rpad(' ', 8));
				addSegment((duration + 'ms').rpad(' ', 8));
				buf.add(req.url.pathWithQuery);
				if(verbose) {
					var hasHeader = false;
					for(header in res.header) {
						hasHeader = true;
						buf.add('\n  ' + header.name + ': ' + header.value);
					}
					if(hasHeader) buf.add('\n');
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
