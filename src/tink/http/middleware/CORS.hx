import tink.http.Method;
import tink.core.Future;
import tink.http.Response.OutgoingResponse;
import tink.http.Request.IncomingRequest;
import tink.http.Handler;
import tink.http.Middleware;
import tink.http.Header;

class CORS implements MiddlewareObject {
    private var origins:Array<String> = ['*'];
    private var methods:Array<String> = ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE'];
    private var headers:Array<String> = ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization'];

    public function new(?origins:Array<String>, ?methods:Array<String>, ?headers:Array<String>) {
        if(origins != null) this.origins = origins;
        if(methods != null) this.methods = methods;
        if(headers != null) this.headers = headers;
    }

    public function apply(handler:Handler):Handler {
        return new CORSHandler(origins, methods, headers, handler);
    }
}

class CORSHandler implements HandlerObject {
    private var origins:String;
    private var methods:String;
    private var headers:String;
    private var handler:Handler;

    public function new(origins:Array<String>, methods:Array<String>, headers:Array<String>, handler:Handler) {
        this.origins = origins.join(' ');
        this.methods = methods.join(',');
        this.headers = headers.join(', ');
        this.handler = handler;
    }

    public function process(req:IncomingRequest):Future<OutgoingResponse> {
        // pre-flight requests
        if(req.header.method == Method.OPTIONS) {
            return Future.sync(OutgoingResponse.blob(200, haxe.io.Bytes.ofString(''), 'text/html; charset=utf-8', [
                new HeaderField('Access-Control-Allow-Origin', origins),
                new HeaderField('Access-Control-Allow-Methods', methods),
                new HeaderField('Access-Control-Allow-Headers', headers)
            ]));
        }

        var res = handler.process(req);
        res.handle(function(response:OutgoingResponse):Void {
            response.header.fields.push(new HeaderField('Access-Control-Allow-Origin', origins));
            response.header.fields.push(new HeaderField('Access-Control-Allow-Headers', headers));
        });
        return res;
    }
}