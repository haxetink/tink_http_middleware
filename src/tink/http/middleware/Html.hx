package tink.http.middleware;

import tink.http.Request;
import tink.http.Response;
import tink.http.Middleware;
import tink.http.Handler;

using tink.CoreApi;

/**
 *  Send an HTML response whenever the client accepts `text/html`
 */
class Html implements MiddlewareObject {
	
	var getHtml:IncomingRequestHeader->Future<String>;
	
	public function new(getHtml)
		this.getHtml = getHtml;
	
	public function apply(handler:Handler):Handler
		return function(req:IncomingRequest)
			return switch req.header.accepts('text/html') {
				case Success(true): getHtml(req.header).map(function(html) return OutgoingResponse.blob(OK, html, 'text/html'));
				default: handler.process(req);
			}
}