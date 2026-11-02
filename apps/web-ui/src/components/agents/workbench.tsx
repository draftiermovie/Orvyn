"use client";
import { useEffect, useRef, useState } from 'react';
import { api, base64, importDocument, readDocument } from '@/lib/workspace';
import { Opex, emptyOpex, type OpexState } from './opex';
import { CodeBlock, DiffView } from './code-content';

type Task={id:string;text:string;done:boolean};
type Card={question:string;answer:string};
export type WorkbenchState={opex?:OpexState;draft:string;before:string;after:string;tasks:Task[];project:{name:string;text:string;selected:boolean}[];prompts:{name:string;text:string}[];profiles:{id:string;name:string;instructions:string}[];profile:string;source:string;translation:string;target:string;meeting:string;notes:string;cards:Card[]};
export const emptyWorkbench:WorkbenchState={draft:'',before:'',after:'',tasks:[],project:[],prompts:[],profiles:[{id:'teacher',name:'Leraar',instructions:'Leg helder uit met voorbeelden. Stel vragen om begrip te controleren.'},{id:'coder',name:'Programmeerhulp',instructions:'Geef correcte, uitlegbare code in fenced codeblokken met de taalnaam.'}],profile:'',source:'',translation:'',target:'English',meeting:'',notes:'',cards:[]};
type Props={state:WorkbenchState;onChange:(s:WorkbenchState)=>void;onClose:()=>void;ask:(prompt:string)=>Promise<string>;context:string;onPrompt:(text:string)=>void;busy:boolean;temporary:boolean;focusTab?:{name:string;id:number};codeInstructions?:string};
const field='w-full rounded-lg border border-white/10 bg-[#252525] p-2 text-sm';
const button='rounded-lg bg-white/10 px-3 py-2 text-xs hover:bg-white/15 disabled:opacity-40';
function arrayResult(value:string):unknown[]{const begin=value.indexOf('['),end=value.lastIndexOf(']');const result=JSON.parse(value.slice(begin,end+1));if(!Array.isArray(result))throw new Error('AI gaf geen geldige lijst. Probeer opnieuw.');return result;}
export function Workbench({state:s,onChange,onClose,ask,context,onPrompt,busy,temporary,focusTab,codeInstructions=""}:Props){
  const [tab,setTab]=useState('Writing'),[error,setError]=useState(''),[working,setWorking]=useState(false),[proposal,setProposal]=useState(''),[instruction,setInstruction]=useState('Maak deze tekst duidelijker.'),[name,setName]=useState(''),[template,setTemplate]=useState('');
  const [docs,setDocs]=useState<{id:string;name:string;collection?:string}[]>([]),[docA,setDocA]=useState(''),[docB,setDocB]=useState(''),[folder,setFolder]=useState(''),[collection,setCollection]=useState('General'),[folders,setFolders]=useState<{folder:string;collection:string}[]>([]);
  const [answers,setAnswers]=useState<Record<number,string>>({}),[grades,setGrades]=useState<Record<number,string>>({});
  const latest=useRef(s);latest.current=s;
  const locked=busy||working;const patch=(v:Partial<WorkbenchState>)=>onChange({...s,...v});
  useEffect(()=>{if(focusTab)setTab(focusTab.name);},[focusTab]);
  async function run(job:()=>Promise<void>){setError('');setWorking(true);try{await job();}catch(e){setError(String(e));}finally{setWorking(false);}}
  function tasks(texts:string[]){patch({tasks:[...s.tasks,...texts.filter(Boolean).map(text=>({id:crypto.randomUUID(),text:text.slice(0,2000),done:false}))]});}
  async function getDocs(){setDocs(await api('/api/documents'));const scan=await api('/api/index/scan',{});setFolders(scan.folders||[]);}
  return <aside aria-label="Workspace" className="flex w-[min(580px,95vw)] shrink-0 flex-col border-l border-white/10 bg-[#171717] max-h-screen overflow-auto p-4 gap-3">
    <div className="flex justify-between"><h2 className="font-semibold">Workspace {temporary?'· tijdelijk':''}</h2><button onClick={onClose} aria-label="Close workspace">✕</button></div>
    <div className="flex flex-wrap gap-1">{['Opex','Writing','Diff','Project','Tasks','Translate','Meeting','Library','Knowledge','Learn'].map(t=><button className={button+(tab===t?' ring-1 ring-teal-400':'')} key={t} onClick={()=>{setTab(t);if(t==='Knowledge')run(getDocs);}}>{t}</button>)}</div>
    {error&&<p role="alert" className="text-sm text-amber-200">{error}</p>}
    {working&&<p role="status" className="text-xs text-teal-300">Working…</p>}
    <fieldset disabled={locked} className="contents">
    {tab==='Opex'&&<Opex project={s.project} state={s.opex||emptyOpex} onChange={opex=>onChange({...latest.current,opex})} onProject={project=>{latest.current={...latest.current,project};onChange(latest.current);}} onImport={()=>setTab('Project')} ask={ask} busy={locked} instructions={codeInstructions}/>}
    {tab==='Writing'&&<>
      <label>Je tekst<textarea aria-label="Schrijftekst" className={field} rows={15} value={s.draft} onChange={e=>patch({draft:e.target.value})}/></label>
      <input aria-label="Schrijfopdracht" className={field} value={instruction} onChange={e=>setInstruction(e.target.value)}/>
      <button disabled={locked||!s.draft.trim()} className={button} onClick={()=>run(async()=>setProposal(await ask(`${instruction}\nGeef alleen de nieuwe tekst.\n\n${s.draft.slice(0,8000)}`)))}>AI-voorstel maken</button>
      {proposal&&<><textarea aria-label="Schrijfvoorstel" className={field} rows={10} readOnly value={proposal}/><button className={button} onClick={()=>{patch({before:s.draft,after:proposal});setTab('Diff');}}>Difference met mijn tekst</button><button className={button} onClick={()=>{patch({draft:proposal});setProposal('');}}>Voorstel overnemen</button></>}
    </>}
    {tab==='Diff'&&<><label>Origineel<textarea aria-label="Originele code" className={field} rows={8} value={s.before} onChange={e=>patch({before:e.target.value})}/></label><label>Voorstel<textarea aria-label="Nieuwe code" className={field} rows={8} value={s.after} onChange={e=>patch({after:e.target.value})}/></label><DiffView before={s.before} after={s.after}/><CodeBlock language="javascript" code={s.after}/></>}
    {tab==='Project'&&<>
      <p className="text-xs text-gray-400">Choose a project folder and select up to 8 source files. Only selected excerpts are shared with chat requests. Maximum 100 files / 2 MB of text.</p>
      <input aria-label="Choose project folder" type="file" multiple {...{webkitdirectory:''} as React.InputHTMLAttributes<HTMLInputElement>} onChange={e=>{const files=Array.from(e.target.files||[]);e.target.value='';run(async()=>{const valid=files.filter(f=>!/(^|\/)(node_modules|\.git|dist|target|build-usb|\.env)(\/|$)/.test(f.webkitRelativePath)&&/\.(tsx?|jsx?|py|rs|go|java|cpp|h|c|md|css|html|json|yaml|yml|toml|sql)$/.test(f.name));if(valid.length>100)throw new Error('Kies een kleinere projectmap (maximaal 100 bronbestanden).');if(valid.reduce((n,f)=>n+f.size,0)>2_000_000)throw new Error('Projectselectie maximaal 2 MB.');const project=[];for(const file of valid)project.push({name:file.webkitRelativePath||file.name,text:await readDocument(file),selected:false});patch({project});});}}/>
      {s.project.map((f,i)=><label key={f.name} className="text-xs break-all"><input type="checkbox" checked={f.selected} disabled={!f.selected&&s.project.filter(v=>v.selected).length>=8} onChange={e=>patch({project:s.project.map((v,j)=>j===i?{...v,selected:e.target.checked}:v)})}/> {f.name} ({f.text.length} tekens)</label>)}
      <button className={button} onClick={()=>patch({project:[]})}>Projectselectie wissen</button>
    </>}
    {tab==='Tasks'&&<>
      <button className={button} disabled={locked||!context} onClick={()=>run(async()=>{const list=arrayResult(await ask(`Haal concrete afspraken en taken uit dit gesprek. Verzin niets. Geef uitsluitend een JSON-array van strings.\n${context.slice(-10000)}`));tasks(list.filter((v):v is string=>typeof v==='string'));})}>Tasks uit gesprek halen</button>
      <form className="flex gap-2" onSubmit={e=>{e.preventDefault();if(template.trim()){tasks([template]);setTemplate('');}}}><input aria-label="New task" className={field} value={template} onChange={e=>setTemplate(e.target.value)}/><button className={button}>Toevoegen</button></form>
      {s.tasks.map(t=><div className="flex gap-2" key={t.id}><input aria-label={`Taak voltooid: ${t.text}`} type="checkbox" checked={t.done} onChange={e=>patch({tasks:s.tasks.map(v=>v.id===t.id?{...v,done:e.target.checked}:v)})}/><span className={t.done?'line-through text-gray-500':'flex-1'}>{t.text}</span><button aria-label={`Taak verwijderen: ${t.text}`} onClick={()=>patch({tasks:s.tasks.filter(v=>v.id!==t.id)})}>✕</button></div>)}
    </>}
    {tab==='Translate'&&<><label>Doeltaal<input className={field} value={s.target} onChange={e=>patch({target:e.target.value})}/></label><div className="grid grid-cols-2 gap-2"><label>Origineel<textarea aria-label="Vertaalbron" className={field} rows={16} value={s.source} onChange={e=>patch({source:e.target.value})}/></label><label>Vertaling<textarea aria-label="Vertaling" className={field} rows={16} value={s.translation} onChange={e=>patch({translation:e.target.value})}/></label></div><button className={button} disabled={locked||!s.source.trim()} onClick={()=>run(async()=>patch({translation:await ask(`Vertaal de volgende tekst naar ${s.target}. Geef uitsluitend de vertaling.\n${s.source.slice(0,8000)}`)}))}>Translate</button></>}
    {tab==='Meeting'&&<><textarea aria-label="Vergadertranscript" className={field} rows={12} placeholder="Plak het transcript…" value={s.meeting} onChange={e=>patch({meeting:e.target.value})}/><button className={button} disabled={locked||!s.meeting.trim()} onClick={()=>run(async()=>patch({notes:await ask(`Verwerk dit vergadertranscript met kopjes Samenvatting, Besluiten en Actiepunten. Noem verantwoordelijke en deadline alleen als die genoemd zijn, anders 'niet genoemd'. Verzin niets.\n${s.meeting.slice(0,10000)}`)}))}>Notities verwerken</button><textarea aria-label="Vergadernotities" className={field} rows={12} value={s.notes} onChange={e=>patch({notes:e.target.value})}/><button disabled={locked||!s.notes} className={button} onClick={()=>run(async()=>{const list=arrayResult(await ask(`Geef uitsluitend de concrete actiepunten uit deze notities als JSON-array van strings.\n${s.notes.slice(0,8000)}`));tasks(list.filter((v):v is string=>typeof v==='string'));setTab('Tasks');})}>Actiepunten als taken</button></>}
    {tab==='Library'&&<>
      <label>Assistentprofiel<select aria-label="Assistentprofiel" className={field} value={s.profile} onChange={e=>patch({profile:e.target.value})}><option value="">Standaardassistent</option>{s.profiles.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
      <input aria-label="Sjabloonnaam" placeholder="Naam" className={field} value={name} onChange={e=>setName(e.target.value)}/><textarea aria-label="Sjabloontekst" placeholder="Prompt of assistentinstructies" className={field} rows={6} value={template} onChange={e=>setTemplate(e.target.value)}/>
      <div className="flex gap-2"><button disabled={!name.trim()||!template.trim()} className={button} onClick={()=>patch({prompts:[...s.prompts,{name,text:template}]})}>Prompt bewaren</button><button disabled={!name.trim()||!template.trim()} className={button} onClick={()=>patch({profiles:[...s.profiles,{id:crypto.randomUUID(),name,instructions:template}]})}>Profiel bewaren</button></div>
      {s.prompts.map((p,i)=><div key={i} className="flex gap-2"><button className={button} onClick={()=>onPrompt(p.text)}>{p.name} gebruiken</button><button onClick={()=>patch({prompts:s.prompts.filter((_,j)=>j!==i)})}>Remove</button></div>)}
      {s.profiles.map(p=><div key={p.id} className="flex gap-2 text-xs"><span>{p.name}</span><button onClick={()=>{setName(p.name);setTemplate(p.instructions);}}>Edit als nieuw profiel</button><button onClick={()=>patch({profiles:s.profiles.filter(v=>v.id!==p.id),profile:s.profile===p.id?'':s.profile})}>Remove</button></div>)}
    </>}
    {tab==='Knowledge'&&<>
      <label>Kennisverzameling<input className={field} value={collection} onChange={e=>setCollection(e.target.value)}/></label>
      <label>USB-submap automatisch indexeren<input aria-label="Indexmap" className={field} placeholder="Bijvoorbeeld docs of projecten/mijn-app" value={folder} onChange={e=>setFolder(e.target.value)}/></label><button disabled={locked||temporary||!folder} className={button} onClick={()=>run(async()=>{setFolders(await api('/api/index/folder',{folder,collection}));setError('Map gekoppeld. Index wordt elke 30 seconden bijgewerkt zolang de app open is.');})}>Map koppelen</button>
      {folders.map(f=><div key={f.folder} className="text-xs break-all">{f.folder} · {f.collection}<button disabled={temporary} className={button} onClick={()=>run(async()=>setFolders(await api('/api/index/folder',{folder:f.folder,remove:true})))}>Ontkoppelen</button></div>)}
      <p className="text-xs text-gray-400">Linked folders remain on this USB. Changed supported files are re-read. Existing document copies are preserved.</p>
      <label>Document A<select className={field} value={docA} onChange={e=>setDocA(e.target.value)}><option value="">Kies…</option>{docs.map(d=><option key={d.id} value={d.id}>{d.collection||'General'} · {d.name}</option>)}</select></label>
      <label>Document B<select className={field} value={docB} onChange={e=>setDocB(e.target.value)}><option value="">Kies…</option>{docs.map(d=><option key={d.id} value={d.id}>{d.collection||'General'} · {d.name}</option>)}</select></label>
      <button className={button} disabled={locked||!docA||!docB||docA===docB} onClick={()=>run(async()=>{const [a,b]=await Promise.all([api('/api/documents/get',{id:docA}),api('/api/documents/get',{id:docB})]);patch({before:a.text,after:b.text});setTab('Diff');})}>Documentverschillen tonen</button>
      <button className={button} disabled={locked||!docA} onClick={()=>run(async()=>{const doc=await api('/api/documents/get',{id:docA});patch({source:doc.text.slice(0,10000)});setTab('Learn');})}>Document gebruiken om te leren</button>
    </>}
    {tab==='Learn'&&<>
      <textarea aria-label="Lesmateriaal" placeholder="Plak lesmateriaal of kies een document bij Knowledge" className={field} rows={8} value={s.source} onChange={e=>patch({source:e.target.value})}/>
      <button className={button} disabled={locked||!s.source.trim()} onClick={()=>run(async()=>{const values=arrayResult(await ask(`Maak 5 oefenvragen/flashcards over dit lesmateriaal. Geef uitsluitend een JSON-array van objecten met question en answer, beide strings.\n${s.source.slice(0,8000)}`));const cards=values.filter((v):v is Card=>!!v&&typeof v==='object'&&typeof(v as Card).question==='string'&&typeof(v as Card).answer==='string');if(!cards.length)throw new Error('Geen geldige kaarten ontvangen');patch({cards});setAnswers({});setGrades({});})}>Flashcards / oefentoets maken</button>
      {s.cards.map((c,i)=><section key={`${i}-${c.question}`} className="rounded-lg border border-white/10 p-3 space-y-2"><p>{i+1}. {c.question}</p><details><summary>Kaart omdraaien / antwoord tonen</summary><p>{c.answer}</p></details><textarea aria-label={`Oefenantwoord ${i+1}`} className={field} value={answers[i]||''} onChange={e=>setAnswers({...answers,[i]:e.target.value})}/><button className={button} disabled={locked||!answers[i]} onClick={()=>run(async()=>{const result=await ask(`Beoordeel dit oefenantwoord. Geef Goed, Deels goed of Onjuist en leg kort uit. Question: ${c.question}\nReferentie: ${c.answer}\nAntwoord leerling: ${answers[i]}`);setGrades(g=>({...g,[i]:result}));})}>Antwoord beoordelen</button>{grades[i]&&<p>{grades[i]}</p>}</section>)}
    </>}
    </fieldset>
  </aside>;
}

export function useDocumentIndex(onStatus:(text:string)=>void,enabled=true){
  const status=useRef(onStatus);status.current=onStatus;
  useEffect(()=>{if(!enabled)return;let stopped=false,running=false;async function tick(){if(running||stopped)return;running=true;try{const data=await api('/api/index/scan',{});for(const item of data.files||[]){if(stopped)break;const bytes=Uint8Array.from(atob(item.base64),(c)=>c.charCodeAt(0));try{await importDocument(new File([bytes],item.name),{source:item.source,collection:item.collection,fingerprint:item.fingerprint});}catch(e){status.current(`Index ${item.name}: ${String(e)}`);}}}catch(e){status.current(`Mapindex: ${String(e)}`);}finally{running=false;}}const timer=setInterval(tick,30000);const first=setTimeout(tick,10000);return()=>{stopped=true;clearTimeout(first);clearInterval(timer);};},[enabled]);
}
export async function exportText(text:string,extension:'txt'|'md'|'pdf'){
  if(extension!=='pdf')return api('/api/export',{text,extension});
  const {jsPDF}=await import('jspdf');const pdf=new jsPDF();pdf.setFontSize(10);let y=15;for(const line of pdf.splitTextToSize(text,180)){if(y>280){pdf.addPage();y=15;}pdf.text(line,15,y);y+=5;}return api('/api/export',{extension,base64:base64(pdf.output('arraybuffer'))});
}
