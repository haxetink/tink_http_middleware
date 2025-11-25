package tink.http.middleware;

import haxe.Timer;
import tink.http.Middleware;

using tink.CoreApi;

/**
 *  Emulate server delay, useful when developing with local server where the response is too fast
 */
class Delay implements MiddlewareObject {
	final delay:Int;

	public function new(delay = 500) {
		this.delay = delay;
	}

	public function apply(handler:Handler):Handler
		return function(req) return Future.irreversible(cb -> {
			final start = Timer.stamp();
			handler.process(req).handle(res -> {
				final remaining = delay - Std.int((Timer.stamp() - start) * 1000);
				if (remaining > 0)
					Timer.delay(cb.bind(res), remaining);
				else
					cb(res);
			});
		});
}
