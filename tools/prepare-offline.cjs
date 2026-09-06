const fs=require('node:fs'),path=require('node:path');
const base=path.resolve(process.argv[2]||'build/web');
if(!fs.existsSync(path.join(base,'index.html')))throw Error('Compile the app first.');
const version=(process.env.GITHUB_SHA||'local-ops').replace(/[^a-z0-9-]/gi,'').slice(0,40);
const file=path.join(base,'stilo-offline-worker.js');fs.writeFileSync(file,fs.readFileSync(file,'utf8').replaceAll('__STILO_OFFLINE_VERSION__',version));
const out=[];function walk(dir){for(const f of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,f.name),rel=path.relative(base,p).replaceAll(path.sep,'/');if(f.isDirectory())walk(p);else if(/^(assets|canvaskit|icons)\//.test(rel)&&/\.(js|wasm|json|bin|png|jpg|svg|ttf|otf|woff2|ogg)$/.test(rel))out.push(rel);else if(!rel.includes('/')&&(/^(main[.\w-]*|flutter_bootstrap[.\w-]*|flutter|sauna-maintenance|chat-audio-capture|voice-capture|offline-client)\.js$/.test(rel)||['index.html','manifest.json','favicon.png'].includes(rel)))out.push(rel);}}
walk(base);if(out.length>900)throw Error('Review cache manifest size');fs.writeFileSync(path.join(base,'offline-manifest.json'),JSON.stringify(out));console.log('Public shell assets:',out.length,'revision',version);
