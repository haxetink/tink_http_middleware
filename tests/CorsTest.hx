package;

import tink.testrunner.*;
import tink.http.middleware.*;
import tink.http.Request;
import tink.http.Response;
import tink.http.Method;
import tink.http.Header;
import tink.Chunk;
import tink.unit.Assert.*;

using tink.CoreApi;

@:asserts
class CorsTest extends TestBase {
	public function new() {}

	@:variant(~/https:\/\/www\.google\.com/, 'https://www.google.com')
	@:variant(~/https:\/\/.*.google\.com/, 'https://www.google.com')
	@:variant(~/https:\/\/.*.google\.com/, 'https://api.google.com')
	public function regex(regex:EReg, origin:String) {
		return new CrossOriginResourceSharing(regex).apply(handler)
			.process(req(OPTIONS, '/', [new HeaderField(ORIGIN, origin)]))
			.map(function(res):Assertions return switch res.header.byName(ACCESS_CONTROL_ALLOW_ORIGIN) {
				case Failure(e): asserts.fail(e);
				case Success(o):
					asserts.assert(o == origin);
					asserts.done();
			});
	}

	@:variant(~/https:\/\/www\.google\.com/, 'https://api.google.com')
	@:variant(~/https:\/\/.*.google\.com/, 'https://www.facebook.com')
	@:variant(~/https:\/\/.*.google\.com/, 'https://api.facebook.com')
	public function rejectedRegex(regex:EReg, origin:String) {
		return new CrossOriginResourceSharing(regex).apply(handler)
			.process(req(OPTIONS, '/', [new HeaderField(ORIGIN, origin)]))
			.map(function(res) return assert(res.header.byName(ACCESS_CONTROL_ALLOW_ORIGIN).match(Failure(_))));
	}

	@:variant('https://www.google.com', 'https://www.google.com')
	@:variant('https://www.google.com', 'https://api.google.com')
	public function url(url:tink.Url, origin:String) {
		return new CrossOriginResourceSharing(url).apply(handler)
			.process(req(OPTIONS, '/', [new HeaderField(ORIGIN, origin)]))
			.map(function(res):Assertions return switch res.header.byName(ACCESS_CONTROL_ALLOW_ORIGIN) {
				case Failure(e): fail(e);
				case Success(o): assert(o == url.toString());
			});
	}

	function handler(req:IncomingRequest)
		return Future.sync(('Done' : OutgoingResponse));
}
