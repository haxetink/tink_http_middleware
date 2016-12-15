package;

import haxe.io.Bytes;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.http.Method;
import tink.http.middleware.*;
import tink.unit.Assert.*;
import tink.io.IdealSource;

using tink.CoreApi;

class TestStatic {
	public function new() {}
	
	@:describe('Get an existing file')
	public function testGet() {
		return new Static('.', '/').apply(handler).process(req(GET, '/data/foo.txt')) >>
			function(res:OutgoingResponse) {
				var result = equals(200, res.header.statusCode);
				return res.body.all() >>
					function(bytes:Bytes) return result && equals(43, bytes.length);
			}
	}
	
	@:describe('Get an nonexistent file')
	public function testGetNonExistent() {
		return new Static('.', '/').apply(handler).process(req(GET, '/data/foo2.txt')) >>
			function(res:OutgoingResponse) {
				var result = equals(200, res.header.statusCode);
				return res.body.all() >>
					function(bytes:Bytes) return result && equals('GET', bytes.toString());
			}
	}
	
	@:describe('Partial contents, both end specified')
	public function testPartialContent() {
		return new Static('.', '/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=0-4')])) >>
			function(res:OutgoingResponse) {
				var result = equals(206, res.header.statusCode);
				return res.body.all() >>
					function(bytes:Bytes) return result && equals('the q', bytes.toString());
			}
	}
	
	@:describe('Partial contents, specified start')
	public function testPartialContentStart() {
		return new Static('.', '/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=10-')])) >>
			function(res:OutgoingResponse) {
				var result = equals(206, res.header.statusCode);
				return res.body.all() >>
					function(bytes:Bytes) return result && equals('brown fox jumps over the lazy dog', bytes.toString());
			}
	}
	
	@:describe('Partial contents, specified end')
	public function testPartialContentEnd() {
		return new Static('.', '/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=-4')])) >>
			function(res:OutgoingResponse) {
				var result = equals(206, res.header.statusCode);
				return res.body.all() >>
					function(bytes:Bytes) return result && equals(' dog', bytes.toString());
			}
	}
	
	@:describe('Post')
	public function testPost() {
		return new Static('.', '/').apply(handler).process(req(POST, '/data/foo.txt')) >>
			function(res:OutgoingResponse) {
				var result = equals(200, res.header.statusCode);
				return res.body.all() >>
					function(bytes:Bytes) return result && equals('POST', bytes.toString());
			}
	}
	
	function req(method:Method, path:String, ?headers:Array<HeaderField>, ?body:String)
		return new IncomingRequest('ip', new IncomingRequestHeader(method, path, '1.1', headers), Plain(body == null ? Empty.instance : body));
	
	function handler(req:IncomingRequest):Future<OutgoingResponse>
		return Future.sync((req.header.method:OutgoingResponse));
}