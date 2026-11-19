import haxe.Json;
import js.lib.Promise;
import Protocol.Snapshot;
import Protocol.Vote;
import Protocol.Decision;

typedef Worker = { var id:String; var exe:String; var args:Array<String>; }
class Server {
    public static final fs:Dynamic=js.Syntax.code("require('node:fs')");
    public static final path:Dynamic=js.Syntax.code("require('node:path')");
    public static final cp:Dynamic=js.Syntax.code("require('node:child_process')");
    public static final process:Dynamic=js.Syntax.code("process");
    public static final root:String=path.dirname(js.Syntax.code("__dirname"));
    public static var workers:Array<Worker>=[];
    static var running=0;
    static var port=3211;
    public static var runtimeRoot:String;
    public static function main() {
        configure();
        if(process.env.PORT!=null) {
            var parsed=Std.parseInt(process.env.PORT);
            if(parsed!=null && parsed>0 && parsed<65536) port=parsed;
        }
        var http:Dynamic=js.Syntax.code("require('node:http')");
        var server:Dynamic=http.createServer(handle);
        server.requestTimeout=20000;
        server.headersTimeout=10000;
        server.on("error",function(e:Dynamic) { trace(Std.string(e.message)); process.exitCode=1; });
        server.listen(port,"127.0.0.1",function() trace("WonkyPong is ready: http://localhost:"+port+"/"));
    }
    public static function configure() {
        if(workers.length>0) return;
        var candidates:Array<String>=[];
        if(process.env.WONKYPONG_TOOLCHAINS!=null) candidates.push(process.env.WONKYPONG_TOOLCHAINS);
        var local=path.join(root,"toolchains.local.txt");
        if(fs.existsSync(local)) candidates.push(StringTools.trim(fs.readFileSync(local,"utf8")));
        candidates.push(path.join(root,"../WonkyCalc/.runtimes"));
        candidates.push(path.join(root,".cache/toolchains/.runtimes"));
        runtimeRoot=candidates[candidates.length-1];
        for(candidate in candidates) if(fs.existsSync(path.join(candidate,"haxe"))) { runtimeRoot=path.resolve(candidate); break; }
        var source=path.join(root,"workers");
        var specs=[
            {id:"prolog", exe:"prolog/bin/swipl.exe", args:["-q","-f",path.join(source,"prolog.pl")]},
            {id:"raku",exe:"raku/rakudo-moar-2026.09-01-win-x86_64-msvc/bin/raku.exe",args:[path.join(source,"raku.raku")]},
            {id:"red",exe:"red.exe",args:[path.join(source,"red.red")]},
            {id:"j",exe:"j/j64/jconsole.exe",args:["-jprofile",path.join(source,"j.ijs")]},
            {id:"rebol",exe:"rebol.exe",args:["-s","--quiet",path.join(source,"rebol.reb")]},
            {id:"bqn",exe:"bqn/bqn/BQN.exe",args:[path.join(source,"bqn.bqn")]},
            {id:"factor",exe:"factor/factor/factor.exe",args:["-no-user-init",path.join(source,"factor.factor")]},
            {id:"rexx",exe:"rexx/rexx.exe",args:[path.join(source,"rexx.rexx")]}
        ];
        for(s in specs) workers.push({id:s.id,exe:path.join(runtimeRoot,s.exe),args:s.args});
        for(id in ["eiffel","mercury","icon"])
            workers.push({id:id,exe:path.join(root,".build/native/"+id+".exe"),args:[]});
        var tcl:String=process.env.WONKYPONG_TCL;
        var python:String=process.env.WONKYPONG_PYTHON;
        if(python==null) python="python";
        workers.push(tcl!=null ? {id:"tcl",exe:tcl,args:[path.join(source,"tcl.tcl")]} :
            {id:"tcl",exe:python,args:[path.join(root,"scripts/tcl-host.py"),path.join(source,"tcl.tcl")]});
        fs.mkdirSync(path.join(root,".cache/sessions"),{recursive:true});
    }
    public static function health():Array<Dynamic> {
        configure();
        return [for(id in Protocol.ids) {
            var w=worker(id);
            var available:Bool=fs.existsSync(w.exe);
            if(id=="tcl" && !available && process.env.WONKYPONG_TCL==null) {
                var p=cp.spawnSync(w.exe,["-c","import tkinter; tkinter.Tcl().eval('info patchlevel')"],{windowsHide:true,timeout:4000});
                available=p.status==0;
            }
            {id:id,name:Protocol.name(id),available:available};
        }];
    }
    public static function worker(id:String):Worker {
        for(w in workers) if(w.id==id) return w;
        throw "Unknown worker.";
    }
    static function json(res:Dynamic,status:Int,value:Dynamic) {
        res.writeHead(status,{"Content-Type":"application/json"}); res.end(Json.stringify(value));
    }
    static function handle(req:Dynamic,res:Dynamic) {
        res.setHeader("Cache-Control","no-store");
        res.setHeader("X-Content-Type-Options","nosniff");
        res.setHeader("Content-Security-Policy","default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' blob: data:; frame-ancestors 'none'; base-uri 'none'");
        var hosts=["localhost:"+port,"127.0.0.1:"+port];
        if(hosts.indexOf(req.headers.host)<0) { json(res,403,{error:"Local requests only."}); return; }
        var origin:String=req.headers.origin;
        if(origin!=null && origin!="http://localhost:"+port && origin!="http://127.0.0.1:"+port) { json(res,403,{error:"Local requests only."}); return; }
        if(req.method=="GET" && req.url=="/api/health") { json(res,200,{project:"WonkyPong",workers:health()}); return; }
        if(req.method=="GET" && (req.url=="/" || req.url=="/wonkypong.js" || req.url=="/favicon.svg")) {
            var name=req.url=="/"?"index.html":req.url.substr(1);
            try {
                var bytes=fs.readFileSync(path.join(root,"public",name));
                res.writeHead(200,{"Content-Type":name=="index.html"?"text/html; charset=utf-8":name=="favicon.svg"?"image/svg+xml":"text/javascript; charset=utf-8"});
                res.end(bytes);
            } catch(e:Dynamic) json(res,404,{error:"Build the Haxe application first."});
            return;
        }
        if(req.method!="POST" || req.url!="/api/session") { json(res,404,{error:"Not found."}); return; }
        if(running>=2) { json(res,429,{error:"Both chambers are occupied. Try again shortly."}); return; }
        var contentType:String=Reflect.field(req.headers,"content-type");
        if(contentType==null || !StringTools.startsWith(contentType,"application/json")) { json(res,415,{error:"Send application/json."}); return; }
        var body=""; var rejected=false;
        req.setEncoding("utf8");
        req.on("data",function(chunk:String) {
            if(rejected) return;
            body+=chunk;
            if(body.length>4096) { rejected=true; json(res,413,{error:"Snapshot too large."}); }
        });
        req.on("end",function() {
            if(rejected) return;
            var snapshot:Snapshot;
            try snapshot=Protocol.validate(Json.parse(body)) catch(e:Dynamic) { json(res,400,{error:Std.string(e)}); return; }
            if(running>=2) { json(res,429,{error:"Both chambers are occupied. Try again shortly."}); return; }
            running++;
            res.writeHead(200,{"Content-Type":"application/x-ndjson; charset=utf-8","X-Accel-Buffering":"no"});
            var job=new Sitting(snapshot,function(event:Dynamic) {
                if(!res.destroyed && !res.writableEnded) res.write(Json.stringify(event)+"\n");
            });
            res.on("close",function() { if(!res.writableEnded) job.cancel(); });
            job.start().then(function(_) {
                running--; if(!res.destroyed) res.end(); return null;
            },function(e:Dynamic) {
                running--;
                if(!res.destroyed) res.end(Json.stringify({type:"error",message:Std.string(e)})+"\n");
                return null;
            });
        });
        req.on("error",function(_:Dynamic) { rejected=true; });
    }
}

class Sitting {
    var state:Snapshot;
    var emit:Dynamic->Void;
    var dir:String;
    var children:Array<Dynamic>=[];
    var cancelled=false;
    var started:Float;
    var votes:Array<Vote>=[];
    public function new(state:Snapshot,emit:Dynamic->Void) {
        this.state=state; this.emit=emit;
        dir=Server.fs.mkdtempSync(Server.path.join(Server.root,".cache/sessions/sitting-"));
        Server.fs.writeFileSync(Server.path.join(dir,"state.txt"),Protocol.encode(state),"utf8");
        for(w in Server.workers) for(arg in w.args)
            if(StringTools.startsWith(arg,Server.path.join(Server.root,"workers")))
                Server.fs.copyFileSync(arg,Server.path.join(dir,Server.path.basename(arg)));
    }
    public function cancel() {
        cancelled=true;
        for(child in children.copy()) kill(child);
    }
    function kill(child:Dynamic) {
        if(child.exitCode!=null || child.pid==null) return;
        if(Server.process.platform=="win32") {
            var killer=Server.cp.spawn("taskkill.exe",["/PID",Std.string(child.pid),"/T","/F"],{windowsHide:true,stdio:"ignore"});
            killer.on("error",function(_:Dynamic) child.kill());
        } else child.kill();
    }
    function run(id:String,extra:Array<String>):Promise<Dynamic> {
        return new Promise(function(resolve,_) {
            if(cancelled) { resolve({ok:false,error:"Sitting cancelled.",ms:0}); return; }
            var w=Server.worker(id); var start=Date.now().getTime(); var output=""; var ended=false; var timedOut=false;
            var args=[for(arg in w.args) StringTools.startsWith(arg,Server.path.join(Server.root,"workers")) ? cast(Server.path.basename(arg),String) : arg];
            var child:Dynamic=Server.cp.spawn(w.exe,args.concat(extra),{cwd:dir,windowsHide:true,stdio:["pipe","pipe","pipe"]});
            children.push(child);
            var timer:Dynamic=js.Syntax.code("setTimeout")(function() { timedOut=true; kill(child); },15000);
            function finish(ok:Bool,message:String) {
                if(ended) return; ended=true;
                js.Syntax.code("clearTimeout")(timer); children.remove(child);
                resolve({ok:ok,error:message,ms:Std.int(Date.now().getTime()-start)});
            }
            child.stdin.on("error",function(_:Dynamic) {}); child.stdin.end();
            child.stdout.on("data",function(b:Dynamic) { output=(output+b.toString()).substr(-2000); });
            child.stderr.on("data",function(b:Dynamic) { output=(output+b.toString()).substr(-2000); });
            child.on("error",function(e:Dynamic) finish(false,id+": "+e.message));
            child.on("close",function(code:Dynamic) finish(code==0 && !timedOut && !cancelled,
                cancelled?"Sitting cancelled.":timedOut?id+" exceeded its 15 second speaking limit.":id+": "+output));
        });
    }
    function read(name:String):String return Server.fs.readFileSync(Server.path.join(dir,name),"utf8");
    function fail(message:String):Dynamic { throw message; }
    function clean() {
        var parent:String=Server.path.resolve(Server.root,".cache/sessions");
        if(Server.path.dirname(Server.path.resolve(dir))==parent) Server.fs.rmSync(dir,{recursive:true,force:true});
    }
    public function start():Promise<Dynamic> {
        started=Date.now().getTime();
        emit({type:"open",count:12});
        var promises:Array<Promise<Dynamic>>=[];
        for(id in Protocol.ids) {
            var senator=id;
            promises.push(run(senator,[]).then(function(result:Dynamic) {
                if(!result.ok) { emit({type:"failed",id:senator,message:result.error}); return result; }
                try {
                    var lines=StringTools.trim(read(senator+".vote")).split("\n");
                    var target=Std.parseInt(lines[0]); var confidence=Std.parseInt(lines[1]);
                    if(target==null || confidence==null || target<60 || target>540 || confidence<0 || confidence>100 || lines.length<3)
                        throw "Invalid ballot from "+senator;
                    var vote:Vote={id:senator,target:target,confidence:confidence,reason:StringTools.trim(lines[2]).substr(0,200),ms:result.ms};
                    votes.push(vote); emit({type:"vote",vote:vote});
                    return {ok:true,error:"",ms:result.ms};
                } catch(e:Dynamic) {
                    emit({type:"failed",id:senator,message:Std.string(e)});
                    return {ok:false,error:senator+": "+Std.string(e),ms:result.ms};
                }
            }));
        }
        return Promise.all(promises).then(function(results:Array<Dynamic>) {
            if(cancelled) return fail("Sitting cancelled.");
            var errors=[for(r in results) if(!r.ok) Std.string(r.error)];
            if(errors.length>0) return fail(errors.join("\n"));
            votes.sort(function(a,b) return Protocol.ids.indexOf(a.id)-Protocol.ids.indexOf(b.id));
            Server.fs.writeFileSync(Server.path.join(dir,"ballots.tsv"),[for(v in votes) [v.id,Std.string(v.target),Std.string(v.confidence),Std.string(v.ms)].join("\t")].join("\n")+"\n","utf8");
            emit({type:"stage",stage:"Raku is counting the division."});
            return run("raku",["tally"]);
        }).then(function(r:Dynamic) {
            if(!r.ok) return fail(r.error);
            emit({type:"stage",stage:"Eiffel is certifying the motion."});
            return run("eiffel",[]);
        }).then(function(r:Dynamic) {
            if(!r.ok || !StringTools.startsWith(read("certified.txt"),"PASSED")) return fail("The motion failed its Eiffel contract.");
            emit({type:"stage",stage:"Icon is entering the result into the record."});
            return run("icon",[]);
        }).then(function(r:Dynamic) {
            if(!r.ok) return fail(r.error);
            if(cancelled) return fail("Sitting cancelled.");
            var b=StringTools.trim(read("bill.txt")).split("\n");
            var decision:Decision={target:Std.parseInt(b[0]),direction:StringTools.trim(b[1]),up:Std.parseInt(b[2]),hold:Std.parseInt(b[3]),down:Std.parseInt(b[4]),
                ms:Std.int(Date.now().getTime()-started),votes:votes,record:StringTools.trim(read("record.txt")),certified:true};
            emit({type:"result",decision:decision}); clean(); return decision;
        }).catchError(function(e:Dynamic):Dynamic { clean(); return fail(Std.string(e)); });
    }
}
