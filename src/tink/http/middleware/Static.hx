package tink.http.middleware;

import haxe.io.Bytes;
import tink.http.Request;
import tink.http.Header;
import tink.http.Response;
import tink.http.Middleware;
import tink.http.Handler;

#if asys
import asys.io.File;
import asys.FileSystem;
import asys.FileStat;
#elseif sys
import sys.io.File;
import sys.FileSystem;
import sys.FileStat;
#end

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
				var result:Promise<OutgoingResponse> = FileSystem.exists(staticPath) >>
					function(exists:Bool)
						return if(exists)
							FileSystem.stat(staticPath) >>
								function(stat:FileStat) return File.getBytes(staticPath) >>
								function(bytes:Bytes) {
									var mime = mime.Mime.lookup(staticPath);
									return partial(req.header, stat, bytes, mime);
								}
						else
							Future.sync(Failure(notFound));
							
				return result.recover(function(_) return handler.process(req));
			#elseif sys
				if(FileSystem.exists(staticPath)) {
					var mime = mime.Mime.lookup(staticPath);
					var stat = FileSyatem.stat(staticPath);
					var bytes = File.getBytes(staticPath);
					return Future.sync(partial(req.header, stat, bytes, mime));
				}
			#else
				#error "Not supported"
			#end
		} 
		
		return handler.process(req);
	}
	
	function partial(header:Header, stat:FileStat, bytes:Bytes, contentType:String) {
		
		var headers = [
			new HeaderField('accept-ranges', 'bytes'),
			new HeaderField('vary', 'Accept-Encoding'),
			new HeaderField('last-modified', stat.mtime),
		];
		
		// ref: https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.35
		switch header.byName('range') {
			case Success(v):
				switch (v:String).split('=') {
					case ['bytes', range]:
						inline function res(pos, len)
							return OutgoingResponse.blob(206, bytes.sub(pos, len), contentType, headers.concat([
								new HeaderField('content-range', 'bytes $pos-${pos + len - 1}/${bytes.length}'),
							]));
							
						switch range.split('-') {
							case ['', Std.parseInt(_) => len]:
								return res(bytes.length - len, len);
							case [Std.parseInt(_) => pos, '']:
								return res(pos, bytes.length - pos);
							case [Std.parseInt(_) => pos, Std.parseInt(_) => end]:
								return res(pos, end - pos + 1);
							default: // unrecognized byte-range-set (should probably return an error)
						}
					default: // unrecognized bytes-unit (should probably return an error)
				}
				
			case Failure(_):
		}
		return OutgoingResponse.blob(bytes, contentType, headers);
	}
}