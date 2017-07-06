package tink.http.middleware;

import httpstatus.HttpStatusCode;
import tink.http.Middleware;
import tink.http.Handler;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.http.Method;

using tink.CoreApi;

class CrossOriginResourceSharing implements MiddlewareObject {
	
	/**
	 *   https://en.wikipedia.org/wiki/Cross-origin_resource_sharing#Headers
	 */
	var processor:CorsProcessor;
	
	public function new(processor)
		this.processor = processor;
	
	public function apply(handler:Handler):Handler {
		return function(req:IncomingRequest) {
			return processor({
					origin: req.header.byName(ORIGIN).orNull(),
					requestMethod: req.header.byName(ACCESS_CONTROL_REQUEST_METHOD).orNull(),
					requestHeaders: req.header.byName(ACCESS_CONTROL_REQUEST_HEADERS).map(function(a:String) return a.split(',').map(StringTools.trim)).orNull(),
				})
					.map(function(res) {
						var headers = [];
						if(res.allowOrigin != null) {
							headers.push(new HeaderField(ACCESS_CONTROL_ALLOW_ORIGIN, res.allowOrigin));
							if(res.allowOrigin != '*') headers.push(new HeaderField(VARY, 'Origin'));
						}
						if(res.allowCredentials == true) headers.push(new HeaderField(ACCESS_CONTROL_ALLOW_CREDENTIALS, 'true'));
						if(res.exposeHeaders != null) headers.push(new HeaderField(ACCESS_CONTROL_EXPOSE_HEADERS, res.exposeHeaders.join(', ')));
						if(res.maxAge != null) headers.push(new HeaderField(ACCESS_CONTROL_MAX_AGE, Std.string(res.maxAge)));
						if(res.allowMethods != null) headers.push(new HeaderField(ACCESS_CONTROL_ALLOW_METHODS, res.allowMethods.join(', ')));
						if(res.allowHeaders != null) headers.push(new HeaderField(ACCESS_CONTROL_ALLOW_HEADERS, res.allowHeaders.join(', ')));
						return headers;
					})
					.flatMap(function(headers) {
						return switch req.header.method {
							case OPTIONS:
								Future.sync(new OutgoingResponse(new ResponseHeader(OK, OK, headers),tink.io.Source.EMPTY));
							case _:
								handler.process(req).map(function(res) return new OutgoingResponse(res.header.concat(headers), res.body));
						}
					});
		}
	}
}

typedef CorsRequest = {
	origin:String,
	?requestMethod:String,
	?requestHeaders:Array<String>,
}

typedef CorsResponse = {
	?allowOrigin:String,
	?allowCredentials:Bool,
	?exposeHeaders:Array<String>,
	?maxAge:Int,
	?allowMethods:Array<Method>,
	?allowHeaders:Array<String>,
}

private typedef Proc = CorsRequest->Future<CorsResponse>;

@:callable
abstract CorsProcessor(Proc) from Proc to Proc {
	
	@:from
	public static function fromRegex(ex:EReg):CorsProcessor {
		return function(req:CorsRequest):Future<CorsResponse> {
			var match = ex.match(req.origin);
			return Future.sync(
				if(ex.match(req.origin)) {
					allowOrigin: match ? req.origin : null,
					allowMethods: match ? allMethods() : null,
					allowHeaders: match ? req.requestHeaders : null,
				} else {}
			);
		}
	}
	
	@:from
	public static function fromUrl(url:tink.Url):CorsProcessor {
		return function(req:CorsRequest):Future<CorsResponse> {
			return Future.sync({
				allowOrigin: url.toString(),
				allowMethods: allMethods(),
				allowHeaders: req.requestHeaders,
			});
		}
	}
	
	static inline function allMethods()
		return [HEAD, GET, POST, PUT, PATCH, DELETE];
}