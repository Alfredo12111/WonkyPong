import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.ButtonElement;
import js.html.DivElement;
import haxe.Json;
import Protocol.Vote;
import Protocol.Decision;
import Protocol.Snapshot;
import Accuracy.AccuracyReport;
import Accuracy.AccuracyScore;

class Main {
    static var canvas:CanvasElement;
    static var ctx:CanvasRenderingContext2D;
    static var game=new Game();
    static var votes:Map<String,Vote>=[];
    static var failed:Map<String,Bool>=[];
    static var ready=false;
    static var healthMessage="Calling the roll…";
    static var stage="The chamber is awaiting a motion.";
    static var error="";
    static var busy=false;
    static var generation=0;
    static var controller:Dynamic;
    static var voteAi=300.0;
    static var voteFlight=0;
    static var nextVoteAt=0.0;
    static var accuracy:AccuracyReport;
    static var approved:Decision;
    static var approvedFlight=-1;
    static var lastApplied=false;
    static var last:Decision;
    static var history:Array<Dynamic>=[];
    static var openedAt=0.0;
    static var selected=-1;
    static var hover=-1;
    static var W=1200.0; static var H=800.0;
    static var pad=32.0; static var left=32.0; static var top=120.0;
    static var lw=800.0; static var lh=550.0;
    static var side=850.0; static var sy=120.0; static var sw=350.0; static var sh=550.0;
    static var bx=56.0; static var by=232.0; static var bw=750.0; static var bh=360.0;
    static var rowH=32.0; static var footerY=700.0;
    static var mobile=false;
    static var primary:ButtonElement; static var pause:ButtonElement;
    static var sound:ButtonElement; static var help:ButtonElement; static var receipt:ButtonElement;
    static var live:DivElement; static var pointer:DivElement;
    static var senatorButtons:Array<ButtonElement>=[];
    static var audio:Dynamic; static var soundOn=false;
    static var keys:Map<String,Bool>=[];
    static var prev=0.0; static var accumulator=0.0;
    static var pointsFlash=0.0;
    static var scoreComment="";
    static var trail:Array<{x:Float,y:Float}>=[];
    static var reduced=false;
    static final bg="#101319";
    static final panel="#171c24";
    static final edge="#2c3441";
    static final white="#edf0e8";
    static final muted="#929ba9";
    static final lime="#c6f36b";
    static final blue="#a7baff";
    static final mono="ui-monospace, Consolas, monospace";
    static final sans="Inter, Segoe UI, Arial, sans-serif";

    static function main() {
        var body=Browser.document.body;
        body.style.margin="0"; body.style.backgroundColor=bg; body.style.color=white;
        body.style.overflowX="hidden"; body.style.overflowY="scroll";
        body.style.fontFamily=sans;
        canvas=Browser.document.createCanvasElement();
        canvas.setAttribute("role","img");
        canvas.setAttribute("aria-label","Pongress. A Pong court with your paddle on the left and twelve programming-language senators controlling the right paddle.");
        body.appendChild(canvas); ctx=canvas.getContext2d();
        live=Browser.document.createDivElement();
        live.setAttribute("aria-live","polite"); live.setAttribute("role","status");
        live.style.position="absolute"; live.style.width="1px"; live.style.height="1px";
        live.style.overflow="hidden"; live.style.clipPath="inset(50%)";
        body.appendChild(live);
        primary=button("Start match",start,true);
        pause=button("Pause",togglePause);
        sound=button("Sound off",function() {
            soundOn=!soundOn; sound.textContent=soundOn?"Sound on":"Sound off";
            sound.setAttribute("aria-pressed",Std.string(soundOn));
            if(soundOn) beep(420);
        });
        help=button("How it works",showHelp);
        receipt=button("Save receipt",download);
        receipt.disabled=true;
        for(i in 0...12) {
            var index=i;
            var b=button("",function() {selected=selected==index?-1:index; announceSenator(index);});
            b.style.backgroundColor="transparent";b.style.border="0";b.style.padding="0";
            b.setAttribute("aria-label",Protocol.names[index]+", "+Protocol.roles[index]+". No ballot yet.");
            b.onfocus=function(_) {selected=index;};
            b.onmouseenter=function(_) {hover=index;};
            b.onmouseleave=function(_) {hover=-1;};
            senatorButtons.push(b);
        }
        pointer=Browser.document.createDivElement();
        pointer.style.position="absolute"; pointer.style.touchAction="none";
        pointer.style.cursor="none"; pointer.setAttribute("aria-hidden","true"); body.appendChild(pointer);
        pointer.addEventListener("pointermove",function(e:js.html.PointerEvent) {
            game.playerTarget=Game.clamp((e.clientY+Browser.window.scrollY-by)/bh*600,60,540);
        });
        pointer.addEventListener("pointerdown",function(e:js.html.PointerEvent) {
            pointer.setPointerCapture(e.pointerId);
            game.playerTarget=Game.clamp((e.clientY+Browser.window.scrollY-by)/bh*600,60,540);
            e.preventDefault();
        });
        canvas.addEventListener("mousemove",function(e:js.html.MouseEvent) {
            var y=e.clientY+Browser.window.scrollY; var x=e.clientX;
            hover=(x>side && x<side+sw && y>sy+164 && y<sy+164+rowH*12)?Std.int((y-sy-164)/rowH):-1;
        });
        canvas.addEventListener("click",function(_:Dynamic) { if(hover>=0) selected=selected==hover?-1:hover; });
        Browser.window.addEventListener("keydown",function(e:js.html.KeyboardEvent) {
            if(Browser.document.querySelector("dialog[open]")!=null) return;
            if(["ArrowUp","ArrowDown","w","W","s","S"].indexOf(e.key)>=0) { keys[e.key]=true; e.preventDefault(); }
            if((e.code=="Space" || e.key=="p" || e.key=="P") && !e.repeat && (cast e.target:js.html.Element).tagName!="BUTTON") {
                e.preventDefault(); if(!game.active && !game.finished) start() else togglePause();
            }
        });
        Browser.window.addEventListener("keyup",function(e:js.html.KeyboardEvent) keys.remove(e.key));
        Browser.window.addEventListener("blur",function(_) { keys.clear(); if(game.active && !game.paused) togglePause(); });
        Browser.document.addEventListener("visibilitychange",function(_) {
            if(Browser.document.hidden && game.active && !game.paused) togglePause();
        });
        game.onVote=function() { if(!busy && error=="") requestVote(); };
        game.onHit=function() beep(520);
        game.onPoint=function(won:Bool) {
            pointsFlash=0.7; beep(won?760:190);
            if(won && approved!=null && approvedFlight==game.flight) {
                var nearest=approved.votes.copy();
                nearest.sort(function(a,b) return Reflect.compare(Math.abs(a.target-game.arrivalY),Math.abs(b.target-game.arrivalY)));
                scoreComment=Math.abs(approved.target-game.arrivalY)<=67?
                    "The motion was sound. The paddle could not reach it in time.":
                    Protocol.name(nearest[0].id)+" was closest to impact at y="+Std.int(game.arrivalY)+". The approved target was "+approved.target+".";
                for(entry in history) if(entry.decision==approved) Reflect.setField(entry,"miss",{
                    impactY:game.arrivalY,paddleAtImpact:game.arrivalPaddle,approvedTarget:approved.target,
                    closestSenator:nearest[0].id,report:scoreComment
                });
            } else scoreComment=won?"The ball arrived before this shot received a certified motion.":"The chamber's return passed. The people failed to receive it.";
            live.textContent=(won?"You score. ":"The chamber scores. ")+game.human+" to "+game.senate+".";
        };
        reduced=Browser.window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        Browser.window.addEventListener("resize",function(_) resize());
        resize(); checkHealth(); Browser.window.requestAnimationFrame(frame);
    }
    static function button(label:String,action:Void->Void,accent=false):ButtonElement {
        var b=Browser.document.createButtonElement(); b.textContent=label;
        b.style.position="absolute"; b.style.height="40px"; b.style.borderRadius="6px";
        b.style.border="1px solid "+(accent?lime:edge); b.style.backgroundColor=accent?lime:panel;
        b.style.color=accent?bg:white; b.style.fontFamily=sans; b.style.fontSize="14px";
        b.style.fontWeight="600"; b.style.padding="0 15px"; b.style.cursor="pointer";
        b.style.zIndex="2"; b.onclick=function(_) action();
        Browser.document.body.appendChild(b); return b;
    }
    static function place(b:ButtonElement,x:Float,y:Float,width:Float) {
        b.style.left=x+"px"; b.style.top=y+"px"; b.style.width=width+"px";
    }
    static function resize() {
        W=Browser.document.documentElement.clientWidth; mobile=W<980; pad=mobile?16:32; left=pad; top=mobile?130:120;
        if(mobile) {
            H=Math.max(1250,Browser.window.innerHeight); lw=W-pad*2; lh=440;
            side=left; sy=top+lh+20; sw=lw; sh=596; footerY=sy+sh+20; H=footerY+166;
        } else {
            H=Math.max(826,Browser.window.innerHeight);
            sw=352; lw=W-pad*2-sw-20; lh=H-230; side=left+lw+20; sy=top; sh=lh; footerY=top+lh+20;
        }
        bx=left+22; by=top+112; bw=lw-44; bh=lh-212; rowH=(sh-200)/12;
        var ratio=Math.min(2,Browser.window.devicePixelRatio);
        canvas.width=Std.int(W*ratio); canvas.height=Std.int(H*ratio);
        canvas.style.width=W+"px"; canvas.style.height=H+"px"; canvas.style.display="block";
        ctx.setTransform(ratio,0,0,ratio,0,0);
        pointer.style.left=bx+"px"; pointer.style.top=by+"px";
        pointer.style.width=bw+"px"; pointer.style.height=bh+"px";
        if(mobile) {
            place(help,pad,76,132); place(sound,pad+142,76,114);
        } else {
            place(help,W-pad-260,28,138); place(sound,W-pad-112,28,112);
        }
        place(receipt,W-pad-126,footerY+(mobile?105:18),126);
        for(i in 0...senatorButtons.length) {
            place(senatorButtons[i],side+10,sy+164+i*rowH,sw-20);
            senatorButtons[i].style.height=rowH+"px";
        }
        positionControls();
    }
    static function positionControls() {
        var overlay=!game.active || game.finished || error!="";
        if(overlay) {
            place(primary,left+(lw-166)/2,by+bh/2+46,166);
            primary.textContent=error!=""?"Retry sitting":game.finished?"Play again":"Start match";
        } else {
            place(primary,left+22,top+lh-57,116); primary.textContent="New match";
        }
        primary.disabled=!ready && error=="";
        primary.style.opacity=primary.disabled?"0.5":"1";
        place(pause,left+148,top+lh-57,94);
        pause.style.display=game.active?"block":"none";
        pause.textContent=game.paused?"Resume":"Pause";
        pointer.style.display=game.active && error==""?"block":"none";
    }
    static function checkHealth() {
        healthMessage="Calling the roll…";
        Browser.window.fetch("/api/health").then(function(r) { if(!r.ok) throw "Server unavailable"; return r.json(); })
        .then(function(data:Dynamic) {
            var workers:Array<Dynamic>=data.workers;
            var missing=[for(w in workers) if(!w.available) Std.string(w.name)];
            ready=workers.length==12 && missing.length==0;
            healthMessage=ready?"All 12 languages are seated.":"Missing: "+missing.join(", ");
            if(!ready) error="Run npm run setup to seat every language.";
            live.textContent=healthMessage; positionControls(); return null;
        }).catchError(function(_:Dynamic) {
            ready=false; error="The local chamber is offline. Start Pongress, then retry.";
            healthMessage="Chamber offline"; positionControls(); return null;
        });
    }
    static function start() {
        if(!ready) { error=""; checkHealth(); return; }
        if(error!="" && game.active) {
            error=""; game.paused=false; nextVoteAt=0;
            if(game.approaching()) requestVote();
            positionControls(); return;
        }
        cancelVote(); votes.clear(); failed.clear(); history=[]; last=null; error="";
        accuracy=null; approved=null; approvedFlight=-1; nextVoteAt=0; lastApplied=false;
        selected=-1; trail=[]; scoreComment=""; receipt.disabled=true; game.reset(); positionControls();
    }
    static function cancelVote() {
        generation++; if(controller!=null) controller.abort(); controller=null; busy=false;
    }
    static function togglePause() {
        if(!game.active) return;
        game.paused=!game.paused; keys.clear(); positionControls();
        live.textContent=game.paused?"Session paused.":"Session resumed.";
    }
    static function requestVote() {
        cancelVote();
        var token=generation;
        votes.clear(); failed.clear(); selected=-1; error=""; busy=true;
        scoreComment="";
        for(i in 0...12) senatorButtons[i].setAttribute("aria-label",Protocol.names[i]+", "+Protocol.roles[i]+". Ballot pending.");
        var snapshot=game.snapshot(); voteAi=snapshot.ai; voteFlight=game.flight;
        accuracy=Accuracy.measure(snapshot,[]);
        openedAt=Browser.window.performance.now(); stage="The floor is open. Twelve opinions incoming.";
        controller=js.Syntax.code("new AbortController()");
        var decoder:Dynamic=js.Syntax.code("new TextDecoder()");
        var buffer="";
        Browser.window.fetch("/api/session",{
            method:"POST",headers:{"Content-Type":"application/json"},
            body:Json.stringify(snapshot),signal:controller.signal
        }).then(function(response) {
            if(!response.ok) throw "The chamber is busy or unavailable. Retry this sitting.";
            var reader:Dynamic=(cast response:Dynamic).body.getReader();
            var pump:Void->Dynamic=null;
            pump=function() return reader.read().then(function(chunk:Dynamic) {
                if(token!=generation) return null;
                if(chunk.done) {
                    if(busy) problem("The sitting ended before a certified vote arrived.");
                    return null;
                }
                buffer+=decoder.decode(chunk.value,{stream:true});
                var cut=buffer.indexOf("\n");
                while(cut>=0) {
                    var line=buffer.substr(0,cut); buffer=buffer.substr(cut+1);
                    if(StringTools.trim(line)!="") receive(Json.parse(line),snapshot);
                    cut=buffer.indexOf("\n");
                }
                return pump();
            });
            return pump();
        }).catchError(function(e:Dynamic) {
            if(token==generation && (e==null || e.name!="AbortError"))
                problem("A language could not finish its sitting. Retry to reconvene the chamber.");
            return null;
        });
    }
    static function receive(event:Dynamic,snapshot:Snapshot) {
        switch(Std.string(event.type)) {
            case "vote":
                var v:Vote=event.vote; votes[v.id]=v;
                updateAccuracy(snapshot);
            case "failed": failed[event.id]=true;
            case "stage": stage=event.stage;
            case "error":
                Browser.console.error(event.message);
                problem("The motion failed. A worker could not submit a valid ballot.");
            case "result":
                last=event.decision;
                updateAccuracy(snapshot);
                lastApplied=game.approve(last.target,voteFlight);
                if(lastApplied) {approved=last;approvedFlight=voteFlight;}
                history.push({sitting:history.length+1,flight:voteFlight,snapshot:snapshot,decision:last,
                    accuracy:accuracy,applied:lastApplied,ballAtDecision:{x:game.x,y:game.y}});
                busy=false; nextVoteAt=Browser.window.performance.now()+250;
                stage=lastApplied?"Motion certified. The paddle has its orders.":"Motion arrived too late for its shot. Filed for the record.";
                receipt.disabled=false;
                live.textContent=stage+" "+closestNames()+" closest to ideal y "+decimal(accuracy.target)+"."; positionControls();
            default:
        }
    }
    static function problem(message:String) {
        busy=false; error=message; game.paused=true; stage="The chamber is in recess.";
        live.textContent=message; positionControls();
    }
    static function announceSenator(index:Int) {
        var v=votes[Protocol.ids[index]];
        live.textContent=v==null?Protocol.names[index]+" has not submitted a ballot.":senatorButtons[index].getAttribute("aria-label");
    }
    static function decimal(value:Float):String {
        var tenths=Math.round(value*10);
        return Std.int(tenths/10)+"."+(tenths%10);
    }
    static function score(id:String):AccuracyScore {
        if(accuracy!=null) for(s in accuracy.scores) if(s.id==id) return s;
        return null;
    }
    static function closestNames():String {
        return accuracy==null || accuracy.closest.length==0?"No ballots yet":[for(id in accuracy.closest) Protocol.name(id)].join(", ");
    }
    static function updateAccuracy(snapshot:Snapshot) {
        accuracy=Accuracy.measure(snapshot,[for(v in votes) v]);
        for(i in 0...12) {
            var v=votes[Protocol.ids[i]];
            if(v==null) continue;
            var s=score(v.id);
            senatorButtons[i].setAttribute("aria-label",Protocol.names[i]+" votes "+Protocol.direction(v.target,voteAi)+
                ", target "+v.target+", "+decimal(s.error)+" court units off ideal "+decimal(accuracy.target)+
                ", rank "+s.rank+(s.rank==1?", closest":"")+", "+v.ms+" milliseconds. "+v.reason);
        }
    }
    static function frame(now:Float) {
        if(W!=Browser.document.documentElement.clientWidth) resize();
        var elapsed=prev==0?0:Math.min(0.05,(now-prev)/1000); prev=now;
        if(game.active && !game.paused && !game.finished) {
            if(keys.exists("ArrowUp")||keys.exists("w")||keys.exists("W")) game.playerTarget-=680*elapsed;
            if(keys.exists("ArrowDown")||keys.exists("s")||keys.exists("S")) game.playerTarget+=680*elapsed;
            game.playerTarget=Game.clamp(game.playerTarget,60,540);
        }
        accumulator+=elapsed;
        while(accumulator>=1/120) { game.step(1/120); accumulator-=1/120; }
        if(game.approaching() && !game.paused && !busy && error=="" && now>=nextVoteAt) requestVote();
        if(game.active && !game.paused && !reduced) {
            trail.push({x:game.x,y:game.y}); if(trail.length>10) trail.shift();
        }
        pointsFlash=Math.max(0,pointsFlash-elapsed);
        positionControls(); draw(now); Browser.window.requestAnimationFrame(frame);
    }
    static function rect(x:Float,y:Float,w:Float,h:Float,color:String) {
        ctx.fillStyle=color; ctx.fillRect(x,y,w,h);
    }
    static function box(x:Float,y:Float,w:Float,h:Float,color:String,border:String) {
        ctx.fillStyle=color; ctx.beginPath();
        var r=10.0;
        ctx.moveTo(x+r,y); ctx.lineTo(x+w-r,y); ctx.quadraticCurveTo(x+w,y,x+w,y+r);
        ctx.lineTo(x+w,y+h-r); ctx.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
        ctx.lineTo(x+r,y+h); ctx.quadraticCurveTo(x,y+h,x,y+h-r);
        ctx.lineTo(x,y+r); ctx.quadraticCurveTo(x,y,x+r,y); ctx.closePath(); ctx.fill();
        if(border!="") {ctx.strokeStyle=border;ctx.lineWidth=1;ctx.stroke();}
    }
    static function text(s:String,x:Float,y:Float,size:Float,color:String,weight="400",font="") {
        ctx.font=weight+" "+size+"px "+(font==""?sans:font);
        ctx.fillStyle=color; ctx.textAlign="left"; ctx.textBaseline="alphabetic"; ctx.fillText(s,x,y);
    }
    static function center(s:String,x:Float,y:Float,size:Float,color:String,weight="400") {
        ctx.font=weight+" "+size+"px "+sans; ctx.fillStyle=color;
        ctx.textAlign="center";ctx.textBaseline="alphabetic";ctx.fillText(s,x,y);ctx.textAlign="left";
    }
    static function fit(s:String,x:Float,y:Float,width:Float,size:Float,color:String,weight="400") {
        ctx.font=weight+" "+size+"px "+sans;
        var shortened=s;
        while(shortened.length>0 && ctx.measureText(shortened).width>width) shortened=shortened.substr(0,shortened.length-1);
        if(shortened.length<s.length) shortened=shortened.substr(0,Std.int(Math.max(0,shortened.length-2)))+"…";
        text(shortened,x,y,size,color,weight);
    }
    static function dot(x:Float,y:Float,r:Float,color:String) {
        ctx.beginPath(); ctx.arc(x,y,r,0,Math.PI*2); ctx.fillStyle=color; ctx.fill();
    }
    static function draw(now:Float) {
        rect(0,0,W,H,bg);
        // The mark is a miniature chamber: two paddles and a voting ball.
        box(pad,28,36,36,lime,""); rect(pad+9,37,3,18,bg);rect(pad+24,37,3,18,bg);dot(pad+18,46,2.5,bg);
        text("pongress",pad+48,54,32,white,"800");
        if(!mobile) {
            rect(pad+218,33,1,28,edge);
            text("A MOTION TO MOVE",pad+234,44,11,muted,"600",mono);
            text("SLIGHTLY UPWARD.",pad+234,61,11,muted,"600",mono);
        }
        rect(pad,90,W-pad*2,1,edge);
        if(!mobile) {
            text("THE PEOPLE vs. THE PROCESS",left,108,11,muted,"600",mono);
            text("TWELVE LANGUAGES. ONE PADDLE.",side,108,11,muted,"600",mono);
        }
        box(left,top,lw,lh,panel,edge);
        box(side,sy,sw,sh,panel,edge);
        var lcenter=left+lw*0.25; var rcenter=left+lw*0.75;
        text("YOU",left+24,top+29,12,lime,"700",mono);
        text("THE CHAMBER",left+lw-150,top+29,12,blue,"700",mono);
        center(Std.string(game.human),lcenter,top+89,58,white,"600");
        center(Std.string(game.senate),rcenter,top+89,58,white,"600");
        center("FIRST TO 7",left+lw/2,top+54,11,muted,"600");
        center("vs",left+lw/2,top+83,16,muted,"400");
        drawCourt(now);
        var status=game.finished?(game.human>=7?"THE PEOPLE HAVE SPOKEN.":"THE MOTION CARRIES."):
            game.paused?"SESSION PAUSED":busy?"DIVISION IN PROGRESS":game.active?"BALL IN PLAY":"READY TO CONVENE";
        dot(bx+4,by+bh+23,3.5,busy?lime:game.paused?muted:blue);
        text(status,bx+15,by+bh+27,11,busy?lime:muted,"600",mono);
        var rallyText="RALLY "+game.rally+"   /   BEST "+game.bestRally;
        ctx.font="11px "+mono;
        text(rallyText,bx+bw-ctx.measureText(rallyText).width,by+bh+27,11,muted,"400",mono);
        if(!game.active && !game.finished) {
            fit(mobile?"Drag to move · W / S · arrows":"MOVE  Mouse / touch / W S / arrows       PAUSE  Space",bx,top+lh-25,bw,12,muted);
        } else if(!mobile) {
            fit("W / S or mouse to move · Space to pause",left+258,top+lh-32,lw-280,12,muted);
        }
        drawChamber(now);
        drawRecord();
        if(!game.active || game.paused || error!="") drawOverlay();
    }
    static function drawCourt(now:Float) {
        box(bx,by,bw,bh,"#11171d","#303a44");
        ctx.save(); ctx.beginPath();ctx.rect(bx+1,by+1,bw-2,bh-2);ctx.clip();
        // Court markings stay deliberately quiet behind the ball.
        for(i in 1...10) rect(bx+bw*i/10,by,1,bh,"#1b242b");
        for(i in 1...6) rect(bx,by+bh*i/6,bw,1,"#1b242b");
        ctx.strokeStyle="#34414a"; ctx.lineWidth=1;ctx.setLineDash([5,8]);
        ctx.beginPath();ctx.moveTo(bx+bw/2,by);ctx.lineTo(bx+bw/2,by+bh);ctx.stroke();ctx.setLineDash([]);
        ctx.beginPath();ctx.ellipse(bx+bw/2,by+bh/2,bw*0.085,bh*0.14,0,0,Math.PI*2);ctx.stroke();
        // Votes really submitted by workers become little ticks at their proposed y.
        for(i in 0...Protocol.ids.length) {
            var v=votes[Protocol.ids[i]];
            if(v!=null) {
                var py=by+v.target/600*bh;
                rect(bx+bw-18-(i%3)*5,py,4,2,Protocol.colors[i]);
            }
        }
        if(accuracy!=null && game.active) {
            var ideal=by+accuracy.target/600*bh;
            ctx.strokeStyle=lime;ctx.lineWidth=1.5;ctx.setLineDash([2,4]);
            ctx.beginPath();ctx.moveTo(bx+bw*0.82,ideal);ctx.lineTo(bx+bw*0.953,ideal);ctx.stroke();ctx.setLineDash([]);
            ctx.beginPath();ctx.arc(bx+bw*0.953,ideal,4,0,Math.PI*2);ctx.stroke();
            text("IDEAL",bx+bw*0.82,ideal-7,9,lime,"600",mono);
        }
        if(approved!=null && game.active) {
            var target=by+game.aiTarget/600*bh;
            ctx.strokeStyle="#677898";ctx.setLineDash([3,5]);
            ctx.beginPath();ctx.moveTo(bx+bw-64,target);ctx.lineTo(bx+bw-8,target);ctx.stroke();ctx.setLineDash([]);
        }
        for(i in 0...trail.length) {
            var p=trail[i];ctx.globalAlpha=i/trail.length*0.18;
            dot(bx+p.x/1000*bw,by+p.y/600*bh,3.5,white);
        }
        ctx.globalAlpha=1;
        var paddleH=120/600*bh;
        box(bx+28/1000*bw,by+(game.player-60)/600*bh,Math.max(7,12/1000*bw),paddleH,lime,"");
        box(bx+960/1000*bw,by+(game.ai-60)/600*bh,Math.max(7,12/1000*bw),paddleH,blue,"");
        if(game.active || game.finished) {
            if(!reduced) {ctx.shadowColor=white;ctx.shadowBlur=12;}
            dot(bx+game.x/1000*bw,by+game.y/600*bh,Math.max(4,7*bw/1000),white);ctx.shadowBlur=0;
        } else {
            dot(bx+bw*0.64,by+bh*0.34,5,white);
        }
        if(pointsFlash>0 && !reduced) {ctx.globalAlpha=pointsFlash*0.08;rect(bx,by,bw,bh,white);ctx.globalAlpha=1;}
        if(busy && game.active && !game.paused) {
            box(bx+bw/2-112,by+bh-45,224,28,"#212b25","#435137");
            center(countVotes()+"/12 ballots received",bx+bw/2,by+bh-26,12,lime,"600");
        }
        ctx.restore();
    }
    static function countVotes():Int {var n=0;for(_ in votes)n++;return n;}
    static function drawChamber(now:Float) {
        text("THE CHAMBER",side+20,sy+29,14,white,"700");
        var tag=busy?"VOTING":ready?"QUORUM 12/12":"ROLL CALL";
        ctx.font="11px "+mono; text(tag,side+sw-20-ctx.measureText(tag).width,sy+28,11,busy?lime:muted,"500",mono);
        fit(busy?(game.paused?"Play paused. Opinions incoming.":"Ball in motion. Opinions incoming."):last!=null?(lastApplied?"Decision passed. Paddle reacting.":"Motion late. Filed without action."):"A coalition of questionable efficiency.",side+20,sy+51,sw-40,12,muted);
        var counts=[0,0,0]; var dirs=["UP","HOLD","DOWN"];
        for(v in votes) counts[dirs.indexOf(Protocol.direction(v.target,voteAi))]++;
        var segment=(sw-48)/3;
        for(i in 0...3) {
            var win=last!=null && !busy && last.direction==dirs[i] && countVotes()==12;
            box(side+20+i*(segment+4),sy+65,segment,26,win?"#293626":"#202732",win?"#617a3b":"");
            center(dirs[i]+"  "+counts[i],side+20+i*(segment+4)+segment/2,sy+83,11,win?lime:muted,"600");
        }
        box(side+20,sy+100,sw-40,44,"#202920","");
        var idealLabel=accuracy==null?"IDEAL TARGET · AWAITING A SHOT":"IDEAL y="+decimal(accuracy.target)+" · "+(countVotes()<12?"CLOSEST SO FAR":"CLOSEST");
        fit(idealLabel,side+30,sy+115,sw-60,9,muted,"600");
        fit(closestNames(),side+30,sy+134,sw-60,12,lime,"600");
        text("SENATOR",side+33,sy+158,9,muted,"500",mono);
        text("VOTE",side+sw-181,sy+158,9,muted,"500",mono);
        ctx.textAlign="right";
        ctx.font="9px "+mono;ctx.fillStyle=muted;
        ctx.fillText("TARGET",side+sw-87,sy+158);ctx.fillText("OFF (u)",side+sw-20,sy+158);ctx.textAlign="left";
        for(i in 0...12) {
            var id=Protocol.ids[i]; var v=votes[id]; var row=sy+164+i*rowH;
            var s=score(id); var closest=s!=null && s.rank==1;
            if(closest) rect(side+10,row,sw-20,rowH,"#202a22");
            if(i==hover || i==selected) rect(side+10,row,sw-20,rowH,"#242d39");
            if(i>0) rect(side+20,row,sw-40,1,"#252d37");
            rect(side+20,row+rowH/2-6,3,12,Protocol.colors[i]);
            fit(Protocol.names[i],side+33,row+rowH/2+5,sw-221,13,closest?lime:white,"500");
            var stance=v!=null?Protocol.direction(v.target,voteAi):failed.exists(id)?"ERROR":busy?"…":"—";
            var color=v!=null?(stance=="UP"?lime:stance=="DOWN"?blue:muted):failed.exists(id)?"#ff8e90":muted;
            text(stance,side+sw-181,row+rowH/2+4,11,color,"600",mono);
            ctx.font="11px "+mono;ctx.fillStyle=muted;ctx.textAlign="right";
            ctx.fillText(v==null?"—":Std.string(v.target),side+sw-87,row+rowH/2+4);
            ctx.fillStyle=closest?lime:muted;
            ctx.fillText(s==null?"—":decimal(s.error),side+sw-20,row+rowH/2+4);ctx.textAlign="left";
        }
        var timing=busy?decimal((now-openedAt)/1000)+"s deliberating · "+(game.paused?"play paused":"ball keeps moving"):last!=null?(last.ms/1000)+"s · "+(lastApplied?"paddle updated":"too late for this shot"):"Lower error wins. Ties share the credit.";
        fit(timing,side+20,sy+sh-13,sw-40,11,muted);
    }
    static function drawRecord() {
        box(left,footerY,W-pad*2,mobile?150:72,"#141920",edge);
        var show=selected>=0?selected:hover;
        var heading="OFFICIAL RECORD";
        var line=history.length==0?"One human. Twelve senators. Absolutely no executive decisions.":last.record.split("\n")[0];
        if(last!=null && !lastApplied) {heading="LATE MOTION";line+=" Arrived too late; paddle orders unchanged.";}
        if(scoreComment!="") {heading="POST-POINT INQUIRY";line=scoreComment;}
        if(show>=0) {
            heading=Protocol.names[show].toUpperCase()+" · "+Protocol.roles[show].toUpperCase();
            var v=votes[Protocol.ids[show]];
            var s=score(Protocol.ids[show]);
            line=v==null?"This senator has not submitted a ballot yet.":"#"+s.rank+" · "+decimal(s.error)+" units off · "+v.ms+"ms. "+v.reason;
        } else if(error!="") {heading="RECESS NOTICE";line=error;}
        else if(busy) {heading="SITTING "+(history.length+1)+" · LIVE PROCEEDINGS";line=stage;}
        text(heading,left+20,footerY+25,10,muted,"600",mono);
        if(mobile) {
            var words=line.split(" ");var row="";var y=footerY+49;var count=0;
            ctx.font="14px "+sans;
            for(word in words) {
                if(ctx.measureText(row+" "+word).width>sw-40 && row!="") {
                    text(row,left+20,y,14,white); y+=19;count++;row="";
                    if(count>=3) break;
                }
                row+=(row==""?"":" ")+word;
            }
            if(count<3 && row!="") text(row,left+20,y,14,white);
        } else fit(line,left+20,footerY+49,W-pad*2-180,14,white);
        if(!mobile) text("HAXE ON THE FLOOR · 12 NATIVE LANGUAGE WORKERS · ZERO SIMULATED BALLOTS",left,H-13,10,"#737e8d","400",mono);
    }
    static function drawOverlay() {
        var paused=game.paused && game.active && error=="";
        ctx.fillStyle="rgba(17,23,29,0.88)";ctx.fillRect(bx+1,by+1,bw-2,bh-2);
        var headline=error!=""?"The chamber is in recess.":game.finished?(game.human>=7?"Democracy defeated.":"The house always wins?"):paused?"Session adjourned.":"Motion to play.";
        center(headline,bx+bw/2,by+bh/2-30,mobile?25:36,white,"700");
        var sub=error!=""?"A valid twelve-language quorum is required.":game.finished?"Final vote: "+game.human+" to "+game.senate+".":paused?"Take your time. The senators certainly do.":"You move a paddle. They form a committee.";
        center(sub,bx+bw/2,by+bh/2+1,mobile?12:15,muted);
        if(paused) center("Press Space or Resume to continue",bx+bw/2,by+bh/2+34,13,lime);
        else if(!game.finished && error=="") center(healthMessage,bx+bw/2,by+bh/2+26,12,lime);
    }
    static function beep(frequency:Float) {
        if(!soundOn) return;
        try {
            if(audio==null) audio=js.Syntax.code("new (window.AudioContext || window.webkitAudioContext)()");
            audio.resume();
            var oscillator=audio.createOscillator();var gain=audio.createGain();
            oscillator.type="sine";oscillator.frequency.value=frequency;
            gain.gain.setValueAtTime(0.035,audio.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001,audio.currentTime+0.07);
            oscillator.connect(gain);gain.connect(audio.destination);
            oscillator.start();oscillator.stop(audio.currentTime+0.08);
        } catch(_:Dynamic) {}
    }
    static function showHelp() {
        if(game.active && !game.paused) togglePause();
        var dialog:js.html.DialogElement=cast Browser.document.createElement("dialog");
        dialog.style.backgroundColor=panel;dialog.style.color=white;dialog.style.border="1px solid "+edge;
        dialog.style.borderRadius="14px";dialog.style.padding="28px";dialog.style.maxWidth="520px";
        dialog.style.width="calc(100% - 88px)";dialog.style.fontFamily=sans;dialog.style.lineHeight="1.65";
        var title=Browser.document.createElement("h2");title.textContent="A very parliamentary Pong.";title.id="help-title";
        dialog.setAttribute("aria-labelledby","help-title");dialog.appendChild(title);
        for(s in [
            "You play the left paddle. Move with your mouse, drag on the court, or use W / S and the arrow keys. First to seven wins.",
            "The ball never waits for a vote. All twelve native language workers study the same snapshot while play continues, and reconvene with a fresh snapshot while the shot is still approaching.",
            "Each proposal becomes UP, HOLD or DOWN relative to the paddle. Raku picks the largest voting bloc; confidence breaks ties. The winning bloc's median target becomes the motion.",
            "Eiffel checks the quorum and court bounds. Icon writes the proceedings. The paddle reacts at a limited speed when the decision arrives. Votes for a shot that has already passed are recorded as late and cannot steer another shot.",
            "Accuracy compares every proposal with the ideal legal paddle center for that snapshot: the ball's predicted height at the chamber, including wall bounces, clamped to the paddle's limits. OFF is the distance in court units, not screen pixels; lower is better. Ties share first place. The green IDEAL marker shows the benchmark, not a paddle instruction.",
            "Hover or tap a senator for its rank, error, execution time and reasoning. Save receipt includes accuracy rankings and whether each decision arrived in time. Space pauses; sound is optional."
        ]) {var p=Browser.document.createParagraphElement();p.textContent=s;p.style.fontSize="16px";dialog.appendChild(p);}
        var close=Browser.document.createButtonElement();close.textContent="Return to the floor";
        close.style.padding="12px 18px";close.style.backgroundColor=lime;close.style.color=bg;
        close.style.border="0";close.style.borderRadius="6px";close.style.fontSize="16px";
        close.onclick=function(_) {dialog.close();};dialog.appendChild(close);
        dialog.addEventListener("close",function(_) {dialog.remove();primary.focus();});
        Browser.document.body.appendChild(dialog);dialog.showModal();
    }
    static function download() {
        if(history.length==0) return;
        var blob=new js.html.Blob([Json.stringify({project:"Pongress",version:2,score:{you:game.human,chamber:game.senate},sittings:history},null,"  ")],{type:"application/json"});
        var url=js.html.URL.createObjectURL(blob);var a=Browser.document.createAnchorElement();
        a.href=url;a.download="pongress-proceedings.json";a.click();
        Browser.window.setTimeout(function() js.html.URL.revokeObjectURL(url),1000);
    }
}
