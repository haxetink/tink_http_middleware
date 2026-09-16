package;

import haxe.io.Bytes;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.http.Method;
import tink.http.middleware.*;
import tink.unit.Assert.*;
#if nodejs
import js.node.Fs;
#end

using haxe.io.Path;
using tink.io.Source;
using tink.CoreApi;

@:asserts
class StaticTest {
	final folder:String;

	public function new() {
		folder = Sys.programPath().directory();
		while (!sys.FileSystem.exists(folder + '/data'))
			folder = folder + '/..';
		folder = folder.normalize();
	}

	@:describe('Get an existing file')
	public function testGet() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data/foo.txt')).next(res -> {
			asserts.assert(res.header.statusCode == 200);
			res.body.all().next(bytes -> {
				asserts.assert(bytes.length == 43);
				asserts.done();
			});
		});
	}

	@:describe('Get an nonexistent file')
	public function testGetNonExistent() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data/foo2.txt')).next(res -> {
			asserts.assert(res.header.statusCode == 200);
			asserts.assert(!res.header.byName('content-range').isSuccess());
			res.body.all().next(bytes -> {
				asserts.assert(bytes.toString() == 'GET');
				asserts.done();
			});
		});
	}

	@:variant('data', '/assets../tests.hxml')
	@:variant('data', '/assets%2e%2e/tests.hxml')
	@:variant('data', '/assets..%2ftests.hxml')
	@:variant('data', '/assets%2e%2e%2ftests.hxml')
	@:variant('data', '/assets%2E%2E%2Ftests.hxml')
	@:variant('data', '/assets.%2e%2ftests.hxml')
	@:variant('data', '/assets%2e.%2ftests.hxml')
	@:variant('data', '/assets%2e%2e%5ctests.hxml')
	@:variant('data', '/assets..\\tests.hxml')
	@:variant('src/tink', '/assets..%2f..%2ftests.hxml')
	@:variant('src/tink', '/assets%2e%2e%2f%2e%2e%2ftests.hxml')
	public function testRestrictToRoot(root:String, path:String) {
		return new Static('$folder/$root', '/assets', {restrictToRoot: true}).apply(handler)
			.process(req(GET, path)).next(res -> {
				res.body.all().next(bytes -> {
					asserts.assert(bytes.toString() == 'GET');
					asserts.done();
				});
			});
	}

	@:variant('data', '/assets../tests.hxml')
	@:variant('data', '/assets%2e%2e/tests.hxml')
	@:variant('data', '/assets..%2ftests.hxml')
	@:variant('data', '/assets%2e%2e%2ftests.hxml')
	@:variant('data', '/assets%2E%2E%2Ftests.hxml')
	@:variant('data', '/assets.%2e%2ftests.hxml')
	@:variant('data', '/assets%2e.%2ftests.hxml')
	@:variant('data', '/assets%2e%2e%5ctests.hxml')
	@:variant('data', '/assets..\\tests.hxml')
	@:variant('src/tink', '/assets..%2f..%2ftests.hxml')
	@:variant('src/tink', '/assets%2e%2e%2f%2e%2e%2ftests.hxml')
	public function testTraversalWithoutRestriction(root:String, path:String) {
		return new Static('$folder/$root', '/assets').apply(handler)
			.process(req(GET, path)).next(res -> {
				res.body.all().next(bytes -> {
					asserts.assert(bytes.toString() == sys.io.File.getContent('$folder/tests.hxml'));
					asserts.done();
				});
			});
	}

	@:describe('Serve files inside the configured root when restricted')
	public function testServeWithinRoot() {
		return new Static('$folder/data', '/assets', {restrictToRoot: true}).apply(handler)
			.process(req(GET, '/assets/foo.txt')).next(res -> {
				res.body.all().next(bytes -> {
					asserts.assert(bytes.length == 43);
					asserts.done();
				});
			});
	}

	#if nodejs
	@:variant('outside.txt', '../tests.hxml', '/assets/outside.txt')
	@:variant('outside-dir', '..', '/assets/outside-dir/tests.hxml')
	public function testRestrictSymlinkToRoot(name:String, target:String, path:String) {
		final link = '$folder/data/$name';
		Fs.symlinkSync(target, link);
		return new Static('$folder/data', '/assets', {restrictToRoot: true}).apply(handler)
			.process(req(GET, path)).next(res -> {
				res.body.all().next(bytes -> {
					Fs.unlinkSync(link);
					asserts.assert(bytes.toString() == 'GET');
					asserts.done();
				});
			});
	}

	@:variant('outside.txt', '../tests.hxml', '/assets/outside.txt')
	@:variant('outside-dir', '..', '/assets/outside-dir/tests.hxml')
	public function testSymlinkWithoutRestriction(name:String, target:String, path:String) {
		final link = '$folder/data/$name';
		Fs.symlinkSync(target, link);
		return new Static('$folder/data', '/assets').apply(handler)
			.process(req(GET, path)).next(res -> {
				res.body.all().next(bytes -> {
					Fs.unlinkSync(link);
					asserts.assert(bytes.toString() == sys.io.File.getContent('$folder/tests.hxml'));
					asserts.done();
				});
			});
	}
	#end

	@:describe('Issue 5: uri with null bytes crashing Static middleware')
	public function testGetUriWithNullBytes() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data\x00/foo.txt\x00')).next(res -> {
			asserts.assert(res.header.statusCode == 200);
			// Make sure ./data/foo.txt is not served in this case:
			asserts.assert(!res.header.byName('content-range').isSuccess());
			res.body.all().next(bytes -> {
				asserts.assert(bytes.toString() == 'GET');
				asserts.done();
			});
		});
	}

	@:describe('Invalid uris should not be handled by Static middleware')
	public function testUrisWork() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/lets-%CREATE%an%invalid_%%%URL%')).next(res -> {
			asserts.assert(res.header.statusCode == 200);
			asserts.assert(!res.header.byName('content-range').isSuccess());
			res.body.all().next(bytes -> {
				asserts.assert(bytes.toString() == 'GET');
				asserts.done();
			});
		});
	}

	@:describe('Partial contents, both end specified')
	public function testPartialContent() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=0-4')])).next(res -> {
			asserts.assert(res.header.statusCode == 206);
			asserts.assert(res.header.byName('content-range').orNull() == 'bytes 0-4/43');
			res.body.all().next(bytes -> {
				asserts.assert(bytes.toString() == 'the q');
				asserts.done();
			});
		});
	}

	@:describe('Partial contents, specified start')
	public function testPartialContentStart() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=25-')])).next(res -> {
			asserts.assert(res.header.statusCode == 206);
			asserts.assert(res.header.byName('content-range').orNull() == 'bytes 25-42/43');
			res.body.all().next(bytes -> {
				asserts.assert(bytes.toString() == ' over the lazy dog');
				asserts.done();
			});
		});
	}

	@:describe('Partial contents, specified end')
	public function testPartialContentEnd() {
		return new Static(folder, '/').apply(handler).process(req(GET, '/data/foo.txt', [new HeaderField('range', 'bytes=-4')])).next(res -> {
			asserts.assert(res.header.statusCode == 206);
			asserts.assert(res.header.byName('content-range').orNull() == 'bytes 39-42/43');
			res.body.all().next(bytes -> {
				asserts.assert(bytes.toString() == ' dog');
				asserts.done();
			});
		});
	}

	@:describe('Post')
	public function testPost() {
		return new Static(folder, '/').apply(handler).process(req(POST, '/data/foo.txt')).next(res -> {
			asserts.assert(res.header.statusCode == 200);
			asserts.assert(!res.header.byName('content-range').isSuccess());
			res.body.all().next(bytes -> {
				asserts.assert(bytes.toString() == 'POST');
				asserts.done();
			});
		});
	}

	@:describe('Post with range')
	public function testPostWithRange() {
		return new Static(folder, '/').apply(handler).process(req(POST, '/data/foo.txt', [new HeaderField('range', 'bytes=-4')])).next(res -> {
			asserts.assert(res.header.statusCode == 200);
			asserts.assert(!res.header.byName('content-range').isSuccess());
			res.body.all().next(bytes -> {
				asserts.assert(bytes.toString() == 'POST');
				asserts.done();
			});
		});
	}

	function req(method:Method, path:String, ?headers:Array<HeaderField>, ?body:String)
		return new IncomingRequest('ip', new IncomingRequestHeader(method, path, '1.1', headers), Plain(body == null ? Source.EMPTY : body));

	function handler(req:IncomingRequest):Future<OutgoingResponse>
		return Future.sync(((req.header.method : String) : OutgoingResponse));
}
