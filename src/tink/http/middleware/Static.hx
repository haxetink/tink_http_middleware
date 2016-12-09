package tink.http.middleware;

import tink.http.Request;
import tink.http.Response;
import tink.http.Middleware;
import tink.http.Handler;

using StringTools;
using tink.CoreApi;

@:require(mime)
class Static implements MiddlewareObject {
	var root:String;
	var prefix:String;
	
	public function new(localFolder:String, urlPrefix:String) {
		root = localFolder;
		prefix = switch urlPrefix.charCodeAt(0) {
			case '/'.code: urlPrefix;
			default: '/$urlPrefix';
		}
	}
	
	public function apply(handler:Handler):Handler
		return new StaticHandler(root, prefix, handler);
}

class StaticHandler implements HandlerObject {
	var root:String;
	var prefix:String;
	var handler:Handler;
	var notFound:Error;
	
	public function new(root, prefix, handler) {
		this.root = root;
		this.prefix = prefix;
		this.handler = handler;
		notFound = new Error(NotFound, 'File Not Found');
	}
	
	public function process(req:IncomingRequest) {
		var path:String = req.header.uri.path;
		if(path.startsWith(prefix)) {
			var staticPath = '$root/' + path.substr(prefix.length);
			#if asys
				var result:Promise<OutgoingResponse> = asys.FileSystem.exists(staticPath) >>
					function(exists:Bool)
						return if(exists) {
							var mime = mime.Mime.lookup(staticPath);
							asys.io.File.getBytes(staticPath) >>
								function(bytes:haxe.io.Bytes) return OutgoingResponse.blob(bytes, mime);
						} else
							Future.sync(Failure(notFound));
							
				return result.recover(function(_) return handler.process(req));
			#elseif sys
				if(sys.FileSystem.exists(staticPath)) {
					var mime = mime.Mime.lookup(staticPath);
					return Future.sync(OutgoingResponse.blob(sys.io.File.getBytes(staticPath), mime));
				}
			#else
				#error "Not supported"
			#end
		} 
		
		return handler.process(req);
	}
}