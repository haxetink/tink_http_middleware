package;

import tink.http.Request;
import tink.http.Response;
import tink.http.Method;
import tink.http.Header;
import tink.Chunk;

class TestBase {
	
	function req(method:Method, url:tink.Url, ?headers:Array<HeaderField>, ?body:Chunk)
		return new IncomingRequest('ip', new IncomingRequestHeader(method, url, headers), Plain(body == null ? tink.io.Source.EMPTY : body));
}