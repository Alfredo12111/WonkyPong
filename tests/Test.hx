import Protocol.Snapshot;
import Protocol.Decision;
import Server.Sitting;
import js.lib.Promise;
class Test {
    static var checks=0;
    static function expect(ok:Bool,message:String) { if(!ok) throw message; checks++; }
    static function snapshot(x=500,y=300,vx=310,vy=135,ai=300):Snapshot
        return {x:x,y:y,vx:vx,vy:vy,ai:ai,player:300,rally:0,human:0,senate:0,seed:42};
    static function main() {
        try {
            physics(); speed(); accuracy(); validation(); Server.configure(); electionRules(); certificate();
            var states=[snapshot(),snapshot(100,100,400,-200,500),snapshot(47,100,100,780,120),snapshot(600,320,400,0,320)];
            var chain:Promise<Dynamic>=Promise.resolve(null);
            for(s in states) {
                var state=s;
                chain=chain.then(function(_) return sitting(state));
            }
            chain.then(function(_) {
                // Independent request directories must preserve conflicting targets.
                return Promise.all([sitting(snapshot(500,90,300,0,300)),sitting(snapshot(500,510,300,0,300))]);
            }).then(function(results:Array<Decision>) {
                expect(results[0].target<results[1].target,"Concurrent sittings contaminated one another.");
                var resultSeen=false;
                var job=new Sitting(snapshot(),function(e:Dynamic) if(e.type=="result") resultSeen=true);
                var pending=job.start(); job.cancel();
                return pending.then(function(_):Dynamic { throw "Cancelled sitting returned a result."; },
                    function(_:Dynamic):Dynamic { expect(!resultSeen,"Cancelled sitting emitted a decision."); return null; });
            }).then(function(_) {
                trace("PASS: "+checks+" checks; six real twelve-language sittings, 1x/2x speed, accuracy, real-time decisions, voting rules, contracts and cancellation.");
                return null;
            }).catchError(function(e:Dynamic) { trace("FAIL: "+Std.string(e));Server.process.exitCode=1;return null;});
        } catch(e:Dynamic) {trace("FAIL: "+Std.string(e));js.Syntax.code("process").exitCode=1;}
    }
    static function physics() {
        var g=new Game();g.active=true;g.playerTarget=999;
        g.step(1/120);
        expect(g.x>500 && g.y>300,"The ball waited for a vote before moving.");
        for(_ in 0...240) g.step(1/120);
        expect(g.player==540,"Human paddle escaped the court.");
        g.paused=true;var old=g.x;g.step(0.02);
        expect(g.x==old,"Pause did not freeze play.");
        g.paused=false;g.y=8;g.vy=-400;g.vx=300;g.step(0.02);
        expect(g.y>=7 && g.vy>0,"Top-wall rebound escaped the court.");
        g.y=592;g.vy=400;g.step(0.02);
        expect(g.y<=593 && g.vy<0,"Bottom-wall rebound escaped the court.");
        g.player=300;g.playerTarget=300;g.x=50;g.y=300;g.vx=-520;g.vy=0;
        var votes=0;g.onVote=function() votes++;
        g.step(0.02);
        expect(g.vx>0 && votes==1,"Human return did not call exactly one sitting.");
        var flight=g.flight;
        g.step(0.02);
        expect(g.x>47,"Human return froze while the chamber was deliberating.");
        expect(g.approve(420,flight),"A timely decision was rejected.");g.ai=300;
        var before=g.ai;g.step(0.02);
        expect(g.ai-before<=5.401,"The chamber paddle teleported.");
        g.x=950;g.y=g.ai;g.vx=520;g.vy=0;g.step(0.02);
        expect(g.vx<0,"Fast shot tunneled through the chamber paddle.");
        expect(!g.approve(100,flight) && g.aiTarget==420,"A late decision steered a returning shot.");
        g.x=950;g.y=100;g.ai=500;g.aiTarget=500;g.vx=520;g.vy=0;g.step(0.02);
        expect(g.vx>0 && g.arrivalY==100 && g.arrivalPaddle==500,"Miss report lost the actual impact geometry.");
        expect(!g.approve(100,flight) && g.aiTarget==500,"A decision steered the paddle after a miss crossed its face.");
        g.human=6;g.senate=2;g.x=1011;g.vx=520;g.y=10;
        var points=0;g.onPoint=function(_) points++;
        g.step(0.02);g.step(0.02);
        expect(g.human==7 && g.finished && !g.active && points==1,"Winning point was counted incorrectly.");
        g.reset();
        expect(g.human==0 && g.senate==0 && !g.finished && g.approaching(),"Restart leaked match state.");
        expect(g.flight!=flight && !g.approve(100,flight) && g.aiTarget==300,"A previous match's decision leaked into the new serve.");
        var freshFlight=g.flight;g.serve(false);g.serve(true);
        expect(!g.approve(100,freshFlight),"An old flight's ballot steered a new incoming shot.");
        g.finished=true;
        expect(!g.approve(100,g.flight),"A ballot steered a finished match.");
    }
    static function speed() {
        var normal=new Game(); var fast=new Game();
        normal.active=true; fast.active=true; fast.setSpeed(2);
        normal.playerTarget=400; fast.playerTarget=400; normal.aiTarget=400; fast.aiTarget=400;
        normal.step(1/120); fast.step(1/120);
        expect(Math.abs((fast.x-500)-2*(normal.x-500))<0.0000001,"2x did not double horizontal ball travel.");
        expect(Math.abs((fast.y-300)-2*(normal.y-300))<0.0000001,"2x did not double vertical ball travel.");
        expect(Math.abs((fast.player-300)-2*(normal.player-300))<0.0000001,"2x did not double the human paddle speed.");
        expect(Math.abs((fast.ai-300)-2*(normal.ai-300))<0.0000001,"2x did not double the chamber paddle speed.");
        expect(fast.vx==normal.vx && fast.vy==normal.vy,"Speed altered the snapshot's game-time trajectory.");
        fast.setSpeed(1); var old=fast.x;fast.step(1/120);
        expect(Math.abs((fast.x-old)-normal.vx/120)<0.0000001,"Returning to normal left a compounded speed multiplier.");
        fast.setSpeed(2);fast.paused=true;old=fast.x;fast.step(1/120);
        expect(fast.x==old,"Double speed bypassed pause.");
        fast.reset();expect(fast.speedMultiplier==2,"New match lost the selected speed.");
        fast.x=952;fast.y=300;fast.ai=300;fast.aiTarget=300;fast.vy=0;fast.step(1/120);
        expect(fast.vx<0 && fast.rally==1,"2x tunneled through or double-counted a paddle hit.");
        fast.human=6;fast.x=1011;fast.vx=520;fast.y=100;var points=0;fast.onPoint=function(_) points++;
        fast.step(1/120);
        expect(fast.human==7 && fast.finished && points==1,"2x counted a winning point twice.");
        var rejected=false;try fast.setSpeed(3) catch(_:Dynamic) rejected=true;
        expect(rejected && fast.speedMultiplier==2,"Unsupported speed changed the game.");
    }
    static function accuracy() {
        // Explicit trajectories exercise reflection, both paddle limits and fractional targets.
        var states=[snapshot(500,300,453,0),snapshot(500,100,453,100),snapshot(500,580,453,100),
            snapshot(500,100,453,-200),snapshot(500,300,151,700),snapshot(500,300,151,-700),snapshot(500,100,300,100)];
        var impacts=[300.0,200,506,114,56,544,251];
        var targets=[300.0,200,506,114,60,540,251];
        for(i in 0...states.length) {
            var report=Accuracy.measure(states[i],[]);
            expect(Math.abs(report.impact-impacts[i])<0.0000001,"Wrong reflected impact for accuracy case "+i);
            expect(Math.abs(report.target-targets[i])<0.0000001,"Accuracy benchmark ignored paddle limits.");
            expect(report.closest.length==0,"Accuracy invented a winner before any ballots.");
        }
        var ballots:Array<Protocol.Vote>=[for(i in 0...4) {
            id:Protocol.ids[i],target:[290,310,320,325][i],confidence:50,reason:"test",ms:1
        }];
        var report=Accuracy.measure(snapshot(500,300,453,0),ballots);
        expect(report.closest.join(",")=="prolog,raku","Equal-distance targets did not share closest credit.");
        expect(report.scores[0].error==10 && report.scores[1].rank==1 && report.scores[2].rank==3,"Error or tied ranking is incorrect.");
        ballots[3].target=300;
        report=Accuracy.measure(snapshot(500,300,453,0),ballots);
        expect(report.closest.join(",")=="red" && report.scores[0].error==0,"The exact ideal target did not win.");
        report=Accuracy.measure(snapshot(500,100,400,135),ballots);
        expect(Math.abs(report.target-252.8875)<0.0000001 && report.scores[0].error>0,"Fractional benchmark was rounded before ranking.");
        var rejected=false;try Accuracy.measure(snapshot(500,300,-310,135),[]) catch(_:Dynamic) rejected=true;
        expect(rejected,"A retreating shot received a fictitious future intercept.");
    }
    static function validation() {
        Protocol.validate(snapshot());checks++;
        for(field in ["x","y","vx","vy","ai","player","rally","human","senate","seed"]) {
            var d:Dynamic=snapshot();Reflect.setField(d,field,"1; quit");
            var rejected=false;try Protocol.validate(d) catch(_:Dynamic) rejected=true;
            expect(rejected,"Non-numeric "+field+" reached a worker.");
        }
        for(value in [Math.NaN,Math.POSITIVE_INFINITY,1.5,-1,1001]) {
            var d:Dynamic=snapshot();d.x=value;var rejected=false;
            try Protocol.validate(d) catch(_:Dynamic) rejected=true;
            expect(rejected,"Invalid snapshot number accepted.");
        }
        var d:Dynamic=snapshot();d.vx=0;var rejected=false;
        try Protocol.validate(d) catch(_:Dynamic) rejected=true;
        expect(rejected,"Stationary horizontal velocity accepted.");
    }
    static function fixture():String {
        var dir=Server.fs.mkdtempSync(Server.path.join(Server.root,".cache/sessions/test-"));
        Server.fs.writeFileSync(Server.path.join(dir,"state.txt"),Protocol.encode(snapshot()));
        return dir;
    }
    static function remove(dir:String) {
        if(Server.path.dirname(Server.path.resolve(dir))==Server.path.resolve(Server.root,".cache/sessions"))
            Server.fs.rmSync(dir,{recursive:true,force:true});
    }
    static function tally(targets:Array<Int>,confidence:Array<Int>,expected:String) {
        var dir=fixture();
        var lines=[for(i in 0...targets.length) Protocol.ids[i]+"\t"+targets[i]+"\t"+confidence[i]+"\t1"];
        Server.fs.writeFileSync(Server.path.join(dir,"ballots.tsv"),lines.join("\n")+"\n");
        var w=Server.worker("raku");
        var p=Server.cp.spawnSync(w.exe,w.args.concat(["tally"]),{cwd:dir,windowsHide:true,timeout:6000,encoding:"utf8"});
        if(expected=="REJECT") expect(p.status!=0,"An incomplete quorum passed.");
        else {
            expect(p.status==0,"Raku failed: "+p.stderr);
            var b=StringTools.trim(Server.fs.readFileSync(Server.path.join(dir,"bill.txt"),"utf8")).split("\n");
            expect(StringTools.trim(b[1])==expected,"Wrong winner: "+b.join(","));
        }
        remove(dir);
    }
    static function electionRules() {
        tally([120,120,120,120,300,300,300,300,480,480,480,480],[for(_ in 0...12) 50],"HOLD");
        tally([120,120,120,120,300,300,300,300,480,480,480,480],[80,80,80,80,50,50,50,50,50,50,50,50],"UP");
        tally([120,120,120,120,120,300,300,300,480,480,480,480],[1,1,1,1,1,100,100,100,100,100,100,100],"UP");
        tally([for(_ in 0...11) 300],[for(_ in 0...11) 50],"REJECT");
    }
    static function certificate() {
        var dir=fixture();Server.fs.writeFileSync(Server.path.join(dir,"bill.txt"),"900\nDOWN\n0\n0\n12\n12\n");
        var w=Server.worker("eiffel");
        var p=Server.cp.spawnSync(w.exe,[],{cwd:dir,windowsHide:true,timeout:6000,encoding:"utf8"});
        expect(p.status!=0,"Eiffel certified an off-court target.");remove(dir);
    }
    static function sitting(state:Snapshot):Promise<Decision> {
        var ballots=0;var result=false;
        var job=new Sitting(state,function(e:Dynamic) {if(e.type=="vote") ballots++;if(e.type=="result") result=true;});
        return job.start().then(function(d:Decision) {
            expect(ballots==12 && d.votes.length==12,"Not all twelve native workers voted.");
            expect(d.certified && result,"The certified result was not emitted.");
            expect(d.up+d.hold+d.down==12,"Tally lost ballots.");
            expect(d.target>=60 && d.target<=540,"Decision escaped the court.");
            expect(d.record.indexOf(d.direction)>=0,"Icon's record disagrees with the election.");
            var accuracy=Accuracy.measure(state,d.votes);
            expect(accuracy.scores.length==12 && accuracy.closest.length>0,"Completed native sitting lost its accuracy ranking.");
            var raw=state.y-7+state.vy*(953-state.x)/state.vx;
            var z=raw-Math.floor(raw/1172)*1172;
            var expected=Game.clamp(7+Math.min(z,1172-z),60,540);
            for(v in d.votes) {
                expect(v.target>=60 && v.target<=540 && v.reason.length>10,"Invalid native ballot.");
                if(["j","rexx","prolog","eiffel","mercury"].indexOf(v.id)>=0)
                    expect(Math.abs(v.target-expected)<=1.1,v.id+" produced the wrong reflected intercept.");
            }
            return d;
        });
    }
}
