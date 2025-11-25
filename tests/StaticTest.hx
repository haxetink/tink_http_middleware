package;

import haxe.io.Bytes;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.http.Method;
import tink.http.middleware.*;
import tink.unit.Assert.*;

using haxe.io.Path;
using tink.io.Source;
using tink.CoreApi;

@:asserts
class StaticTest {
	var folder:String;

	public function new() {
		folder = Sys.programPath().directory();
		while (!sys.FileSystem.exists(folder + '/data'))
			folder = folder + '/..';
		folder = folder.normalize();
	}

	@:describe('Get an existing file')
	public function testGet() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data/foo.txt')) >> function(res:OutgoingResponse) {
			asserts.assert(res.header.statusCode == 200);
			return res.body.all().next(function(bytes) {
				asserts.assert(bytes.length == 43);
				return asserts.done();
			});
		}
	}

	@:describe('Get an nonexistent file')
	public function testGetNonExistent() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data/foo2.txt')) >> function(res:OutgoingResponse) {
			asserts.assert(res.header.statusCode == 200);
			asserts.assert(!res.header.byName('content-range').isSuccess());
			return res.body.all().next(function(bytes) {
				asserts.assert(bytes.toString() == 'GET');
				return asserts.done();
			});
		}
	}

	@:describe('Issue 5: uri with null bytes crashing Static middleware')
	public function testGetUriWithNullBytes() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data\x00/foo.txt\x00')) >> function(res:OutgoingResponse) {
			asserts.assert(res.header.statusCode == 200);
			// Make sure ./data/foo.txt is not served in this case:
			asserts.assert(!res.header.byName('content-range').isSuccess());
			return res.body.all().next(function(bytes) {
				asserts.assert(bytes.toString() == 'GET');
				return asserts.done();
			});
		}
	}

	@:describe('Invalid uris should not be handled by Static middleware')
	public function testUrisWork() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/lets-%CREATE%an%invalid_%%%URL%')) >> function(res:OutgoingResponse) {
			asserts.assert(res.header.statusCode == 200);
			asserts.assert(!res.header.byName('content-range').isSuccess());
			return res.body.all().next(function(bytes) {
				asserts.assert(bytes.toString() == 'GET');
				return asserts.done();
			});
		}
	}

	@:describe('Partial contents, both end specified')
	public function testPartialContent() {
		return new Static(folder,
			'/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=0-4')])) >> function(res:OutgoingResponse) {
				asserts.assert(res.header.statusCode == 206);
				asserts.assert(res.header.byName('content-range').orNull() == 'bytes 0-4/43');
				return res.body.all().next(function(bytes) {
					asserts.assert(bytes.toString() == 'the q');
					return asserts.done();
				});
			}
	}

	@:describe('Partial contents, specified start')
	public function testPartialContentStart() {
		return new Static(folder,
			'/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=25-')])) >> function(res:OutgoingResponse) {
				asserts.assert(res.header.statusCode == 206);
				asserts.assert(res.header.byName('content-range').orNull() == 'bytes 25-42/43');
				return res.body.all().next(function(bytes) {
					asserts.assert(bytes.toString() == ' over the lazy dog');
					return asserts.done();
				});
			}
	}

	@:describe('Partial contents, specified end')
	public function testPartialContentEnd() {
		return new Static(folder,
			'/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=-4')])) >> function(res:OutgoingResponse) {
				asserts.assert(res.header.statusCode == 206);
				asserts.assert(res.header.byName('content-range').orNull() == 'bytes 39-42/43');
				return res.body.all().next(function(bytes) {
					asserts.assert(bytes.toString() == ' dog');
					return asserts.done();
				});
			}
	}

	@:describe('Post')
	public function testPost() {
		return new Static(folder, '/').apply(handler).process(req(POST, '/data/foo.txt')) >> function(res:OutgoingResponse) {
			asserts.assert(res.header.statusCode == 200);
			asserts.assert(!res.header.byName('content-range').isSuccess());
			return res.body.all().next(function(bytes) {
				asserts.assert(bytes.toString() == 'POST');
				return asserts.done();
			});
		}
	}

	@:describe('Post with range')
	public function testPostWithRange() {
		return new Static(folder,
			'/').apply(handler).process(req(POST, '/data/foo.txt', [new HeaderField('range', 'bytes=-4')])) >> function(res:OutgoingResponse) {
				asserts.assert(res.header.statusCode == 200);
				asserts.assert(!res.header.byName('content-range').isSuccess());
				return res.body.all().next(function(bytes) {
					asserts.assert(bytes.toString() == 'POST');
					return asserts.done();
				});
			}
	}

	function req(method:Method, path:String, ?headers:Array<HeaderField>, ?body:String)
		return new IncomingRequest('ip', new IncomingRequestHeader(method, path, '1.1', headers), Plain(body == null ? Source.EMPTY : body));

	function handler(req:IncomingRequest):Future<OutgoingResponse>
		return Future.sync(((req.header.method : String) : OutgoingResponse));
}
