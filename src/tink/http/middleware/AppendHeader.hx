package tink.http.middleware;

import tink.http.Header;
import tink.http.Response;
import tink.http.Middleware;

using tink.CoreApi;

/**
 *  Append HTTP Header
 */
class AppendHeader implements MiddlewareObject {
	final appender:Appender;

	public function new(appender) {
		this.appender = appender;
	}

	public function apply(handler:Handler):Handler
		return req -> handler.process(req).flatMap(res -> appender(res).map(headers -> new OutgoingResponse(res.header.concat(headers), res.body)));
}

@:callable
private abstract Appender(OutgoingResponse->Future<Array<HeaderField>>) from OutgoingResponse->Future<Array<HeaderField>> {
	@:from public static inline function fromHeader(header:HeaderField):Appender
		return fromHeaders([header]);

	@:from public static inline function fromHeaders(headers:Array<HeaderField>):Appender
		return _ -> Future.sync(headers);
}
