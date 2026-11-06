import http from 'http'; import fs from 'fs'; import path from 'path';
import puppeteer from 'puppeteer-core'; import {Chess} from 'chess.js';
const ROOT=path.dirname(new URL(import.meta.url).pathname);
const PIECES='/Users/thierry/scripts/yolo/piece-sets';
const [,, posFile, outDir, nStr, seedStr] = process.argv;
const N=+nStr; let seed=+seedStr||1; const rnd=()=>{seed=(seed*1664525+1013904223)%4294967296;return seed/4294967296};
const pick=a=>a[Math.floor(rnd()*a.length)];
const HELD=['merida','xkcd','celtic','pixel','governor','mpchess'];
const all=fs.readdirSync(PIECES).filter(d=>!d.startsWith('cc_')&&!d.startsWith('kid_')&&fs.existsSync(`${PIECES}/${d}/wK.svg`));
const MODE=process.env.SETMODE||'all';
const sets=MODE==='train'?all.filter(d=>!HELD.includes(d)):MODE==='held'?all.filter(d=>HELD.includes(d)):all;
const srv=http.createServer((q,s)=>{let u=decodeURIComponent(q.url.split('?')[0]);let f;
 if(u.startsWith('/pieces/'))f=PIECES+u.slice(7);else if(u==='/')f=ROOT+'/page.html';else f=ROOT+u;
 fs.readFile(f,(e,d)=>{if(e){s.writeHead(404);s.end();return}s.writeHead(200,{'content-type':f.endsWith('.js')?'text/javascript':f.endsWith('.css')?'text/css':f.endsWith('.svg')?'image/svg+xml':'text/html'});s.end(d)})}).listen(0);
await new Promise(r=>srv.on('listening',r)); const port=srv.address().port;
const palettes=[['#f0d9b5','#b58863'],['#dee3e6','#8ca2ad'],['#eeeed2','#769656'],['#ececec','#a0a0a0'],['#e8dff2','#8e72b0'],['#f3e6cf','#c28d57'],['#fce4b2','#9a6a3a'],['#e0eef7','#5b8db8'],['#f7f7f7','#6f8f6f'],['#ffffff','#7b8fa1'],['#e6d3b3','#7d5a3c'],['#d9e4dd','#5d7f6b']];
const positions=JSON.parse(fs.readFileSync(posFile));
const browser=await puppeteer.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:'new'});
fs.mkdirSync(outDir,{recursive:true});
const page=await browser.newPage();
const letters='abcdefgh';
for(let i=0;i<N;i++){
  const p=positions[i%positions.length]; const ch=new Chess(p.fen);
  const orientation=rnd()<.5?'white':'black';
  const W=Math.round(300+rnd()*500), dpr=pick([1,2,3]);
  const [light,dark]=pick(palettes); const set=pick(sets);
  const style={hl:pick(['rgba(155,199,0,.41)','rgba(255,255,0,.45)','rgba(205,210,106,.6)','rgba(255,170,0,.4)']),sel:pick(['rgba(20,85,30,.5)','rgba(255,255,0,.5)','rgba(100,150,255,.5)']),dot:pick(['rgba(20,85,30,.5)','rgba(0,0,0,.2)','rgba(0,0,0,.12)','rgba(80,80,80,.35)','rgba(255,255,255,.35)']),dotr:0.05+rnd()*0.12,ring:rnd()<.5};
  const flags={coords:rnd()<.8, lastMove:rnd()<.7, sel:rnd()<.35, arrows:rnd()<.3, chrome:rnd()<.8};
  const moves=ch.moves({verbose:true}); const cfg={style,width:W,set,capSet:pick(sets),light,dark,
    bg:pick(['#161512','#f0f0f0','#2e2a24','#ffffff']),fg:'#999',avatar:pick(['#888','#c33','#37a']),rating:'1500',
    fen:p.fen.split(' ')[0],orientation,coords:flags.coords,chrome:flags.chrome,coordColor:'#888',
    capTop:[],capBot:[]};
  const fenBoard=p.fen.split(' ')[0];
  if(p.last) {cfg.lastMove=flags.lastMove?p.last:undefined;}
  if(ch.inCheck())cfg.check=true;
  if(flags.sel&&moves.length){const pc=pick(moves.filter(m=>m.color===ch.turn()));if(pc){cfg.sel=pc.from;cfg.dests=moves.filter(m=>m.from===pc.from).map(m=>m.to);}}
  if(flags.arrows){cfg.shapes=[...Array(1+Math.floor(rnd()*3))].map(()=>({orig:letters[Math.floor(rnd()*8)]+(1+Math.floor(rnd()*8)),dest:letters[Math.floor(rnd()*8)]+(1+Math.floor(rnd()*8)),brush:pick(['green','red','blue','yellow'])}));}
  // pièces capturées (miniatures) : manquantes par rapport au matériel initial
  const cnt={}; for(const c of fenBoard)if(/[a-zA-Z]/.test(c))cnt[c]=(cnt[c]||0)+1;
  const init={p:8,n:2,b:2,r:2,q:1,k:1}; for(const k in init){const w=Math.max(0,init[k]-(cnt[k.toUpperCase()]||0)),b=Math.max(0,init[k]-(cnt[k]||0));
    for(let j=0;j<Math.min(w,3);j++)cfg.capTop.push('w'+k.toUpperCase()); for(let j=0;j<Math.min(b,3);j++)cfg.capBot.push('b'+k.toUpperCase());}
  const vw=flags.chrome?W+Math.round(rnd()*80):W+Math.round(rnd()*60); 
  await page.setViewport({width:vw,height:Math.round(W*1.9),deviceScaleFactor:dpr});
  await page.goto(`http://localhost:${port}/`); await page.waitForFunction('window.ready===true');
  const r=await page.evaluate(c=>window.render(c),cfg);
  await new Promise(r=>setTimeout(r,60));
  const name=String(i).padStart(4,'0'); await page.screenshot({path:`${outDir}/${name}.png`,fullPage:false});
  // vérité terrain dans l'ORIENTATION de l'image : ligne 0 en haut
  const rows=fenBoard.split('/').map(r=>r.replace(/\d/g,d=>'.'.repeat(+d)));
  const grid=orientation==='white'?rows:rows.slice().reverse().map(r=>r.split('').reverse().join(''));
  fs.writeFileSync(`${outDir}/${name}.json`,JSON.stringify({fen:p.fen,orientation,grid,bbox:r.map(v=>v*dpr),dpr,set,light,dark,flags,coordsOn:flags.coords}));
}
await browser.close(); srv.close();
