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

using haxe.io.Path;
using StringTools;
using tink.io.Source;
using tink.CoreApi;

@:require(mime)
class Static implements MiddlewareObject {
	var root:String;
	var prefix:String;
	
	public function new(localFolder:String, urlPrefix:String) {
		root = (localFolder.isAbsolute() ? localFolder : (Sys.programPath().directory() + '/$localFolder').normalize()).addTrailingSlash();
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
		var path:String = req.header.url.path;
		if(req.header.method == GET && path.startsWith(prefix)) {
			var staticPath = '$root/' + path.substr(prefix.length);
			#if asys
				var result:Promise<OutgoingResponse> = FileSystem.exists(staticPath) >>
					function(exists:Bool) return if(!exists) Future.sync(Failure(notFound)) else FileSystem.isDirectory(staticPath) >>
					function(isDir:Bool) return if(isDir) Future.sync(Failure(notFound)) else FileSystem.stat(staticPath) >>
					function(stat:FileStat) {
						var mime = mime.Mime.lookup(staticPath);
						return partial(req.header, stat, File.readStream(staticPath).idealize(function(_) {}), mime, staticPath.withoutDirectory());
					}
							
				return result.recover(function(_) return handler.process(req));
			#elseif sys
				if(FileSystem.exists(staticPath) && !FileSystem.isDirectory(staticPath)) {
					var mime = mime.Mime.lookup(staticPath);
					var stat = FileSystem.stat(staticPath);
					var bytes = File.getBytes(staticPath);
					return Future.sync(partial(req.header, stat, bytes, mime, staticPath.withoutDirectory()));
				}
			#else
				#error "Not supported"
			#end
		} 
		
		return handler.process(req);
	}
	
	function partial(header:Header, stat:FileStat, source:IdealSource, contentType:String, filename:String) {
		
		var headers = [
			new HeaderField('Accept-Ranges', 'bytes'),
			new HeaderField('Vary', 'Accept-Encoding'),
			new HeaderField('Last-Modified', stat.mtime),
			new HeaderField('Content-Type', contentType),
			new HeaderField('Content-Disposition', 'inline; filename="$filename"'),
		];
		
		// ref: https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.35
		switch header.byName('range') {
			case Success(v):
				switch (v:String).split('=') {
					case ['bytes', range]:
						function res(pos:Int, len:Int) {
							return new OutgoingResponse(
								new ResponseHeader(206, 'Partial Content', headers.concat([
									new HeaderField('Content-Range', 'bytes $pos-${pos + len - 1}/${stat.size}'),
									new HeaderField('Content-Length', len),
								])),
								source.skip(pos).limit(len)
							);
						} 
							
						switch range.split('-') {
							case ['', Std.parseInt(_) => len]:
								return res(stat.size - len, len);
							case [Std.parseInt(_) => pos, '']:
								return res(pos, stat.size - pos);
							case [Std.parseInt(_) => pos, Std.parseInt(_) => end]:
								return res(pos, end - pos + 1);
							default: // unrecognized byte-range-set (should probably return an error)
						}
					default: // unrecognized bytes-unit (should probably return an error)
				}
				
			case Failure(_):
		}
		return new OutgoingResponse(
			new ResponseHeader(200, 'OK', headers.concat([
				new HeaderField('Content-Length', stat.size),
			])),
			source
		);
	}
}