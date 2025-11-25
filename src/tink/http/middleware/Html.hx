package tink.http.middleware;

import tink.http.Request;
import tink.http.Response;
import tink.http.Middleware;
import tink.http.Handler;

#if asys
using asys.io.File;
using asys.FileSystem;
#elseif sys
using sys.io.File;
using sys.FileSystem;
#end
using StringTools;
using haxe.io.Path;
using tink.CoreApi;

/**
 *  Send an HTML response whenever the client accepts `text/html`
 */
class Html implements MiddlewareObject {
	static final CWD = Sys.getCwd();

	final getHtml:IncomingRequestHeader->Future<Option<String>>;

	public function new(getHtml)
		this.getHtml = getHtml;

	public function apply(handler:Handler):Handler
		return req -> switch req.header.accepts('text/html') {
			case Success(true):
				getHtml(req.header).flatMap(o -> switch o {
					case Some(html): Future.sync(OutgoingResponse.blob(OK, html, 'text/html'));
					case None: handler.process(req);
				});
			default:
				handler.process(req);
		}

	/**
	 *  Shorthand for serving an html file
	 *  If `path` starts with `./`, it is relative to cwd of the process
	 *  Otherwise it is relatiave to `Sys.programPath()`
	 */
	public static function file(path:String):Future<Option<String>> {
		final path = if (path.isAbsolute()) path; else if (path.startsWith('./')) Path.join([CWD, path]) else Path.join([Sys.programPath().directory(), path]);

		return #if asys
			path.getContent().asPromise().next(Some).recover(_ -> None);
		#else
			Future.sync(if (path.exists()) Some(path.getContent()) else None);
		#end
	}
}
