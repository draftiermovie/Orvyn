"use client";
import {useEffect,useRef,useState} from 'react';
import {ArrowUp,Check,ChevronRight,Code2,FileText,Folder,FolderOpen,LoaderCircle,Plus,Search,Square,Terminal,X} from 'lucide-react';
import {api} from '@/lib/workspace';
import {emptyWork,workPrompt,type WorkState,type WorkTask,type WorkEvent,type WorkProposal} from '@/lib/opex-work';
import {CodeContent,DiffView} from './code-content';

type Props={state:WorkState;onChange:(s:WorkState)=>void;ask:(prompt:string,signal:AbortSignal,onText:(text:string)=>void)=>Promise<string>;onActivity:(busy:boolean)=>void;models:{id:string;name:string;remote?:boolean}[];model:string;onModel:(id:string)=>void;instructions:string;disabled:boolean;enterToSend:boolean};
const statusName={idle:'Ready to start',working:'Working',approval:'Waiting for you',done:'Completed',stopped:'Paused',error:'Needs attention'};
const field='ow-field';
export default function OpexWorkspace({state=emptyWork,onChange,ask,onActivity,models,model,onModel,instructions,disabled,enterToSend}:Props){
  const latest=useRef(state);latest.current=state;
  const [folder,setFolder]=useState(''),[query,setQuery]=useState(''),[fileQuery,setFileQuery]=useState('');
  const [files,setFiles]=useState<{path:string;directory:boolean}[]>([]),[connected,setConnected]=useState(''),[truncated,setTruncated]=useState(false);
  const [busy,setBusy]=useState(false),[phase,setPhase]=useState(''),[error,setError]=useState(''),[stream,setStream]=useState('');
  const [proposal,setProposal]=useState<Extract<WorkProposal,{action:'write'|'run'}>|null>(null),[panel,setPanel]=useState<'files'|'changes'|'terminal'>('files');
  const [preview,setPreview]=useState<{path:string;text:string}|null>(null),[liveOutput,setLiveOutput]=useState(''),[selectedChange,setSelectedChange]=useState('');
  const operation=useRef(false),stopped=useRef(false),controller=useRef<AbortController|null>(null),jobId=useRef(''),end=useRef<HTMLDivElement>(null),cancelPending=useRef<Promise<unknown>|null>(null);
  const task=state.tasks.find(t=>t.id===state.active),locked=busy||disabled;
  const changes=task?.events.filter(e=>e.kind==='write')||[],commands=task?.events.filter(e=>e.kind==='run')||[];
  const change=changes.find(e=>e.id===selectedChange)||changes.at(-1);
  const remote=models.find(m=>m.id===model)?.remote;
  function save(next:WorkState){latest.current=next;onChange(next);}
  function current(id:string){const t=latest.current.tasks.find(t=>t.id===id);if(!t)throw Error('Task not found.');return t;}
  function patch(id:string,fields:Partial<WorkTask>){save({...latest.current,tasks:latest.current.tasks.map(t=>t.id===id?{...t,...fields,updatedAt:Date.now()}:t)});}
  function record(id:string,event:Omit<WorkEvent,'id'|'time'>){const entry={...event,id:crypto.randomUUID(),time:Date.now()};patch(id,{events:[...current(id).events,entry]});return entry;}
  useEffect(()=>{setFolder(task?.folder||'');setConnected('');setFiles([]);setPreview(null);setProposal(null);setError('');setStream('');setLiveOutput('');},[state.active]);
  useEffect(()=>{end.current?.scrollIntoView({behavior:'smooth',block:'nearest'});},[task?.events.length,phase,proposal]);
  useEffect(()=>()=>{stopped.current=true;controller.current?.abort();if(jobId.current)void api('/api/opex/stop',{id:jobId.current}).catch(()=>{});
    const active=latest.current.tasks.find(t=>t.id===latest.current.active);if(active?.status==='approval')patch(active.id,{status:'stopped'});
  },[]);
  function pauseProposal(){if(proposal&&latest.current.active){const id=latest.current.active;record(id,{kind:'notice',text:'Proposal was not executed. Request a new step when you resume this task.'});patch(id,{status:'stopped'});setProposal(null);}}
  function switchTask(id:string){if(locked)return;pauseProposal();save({...latest.current,active:id});}
  function newTask(){if(locked||operation.current)return;pauseProposal();const id=crypto.randomUUID(),now=Date.now();save({active:id,tasks:[{id,title:'New task',folder:task?.folder||folder,createdAt:now,updatedAt:now,events:[],draft:'',status:'idle',strategy:'act'},...latest.current.tasks]});}
  async function operationRun(fn:()=>Promise<void>){
    if(operation.current)return;operation.current=true;setBusy(true);onActivity(true);setError('');stopped.current=false;
    const id=latest.current.active;
    try{await fn();}catch(e){if(id){record(id,{kind:stopped.current?'notice':'error',text:stopped.current?'Task stopped. Saved changes are preserved.':String(e)});patch(id,{status:stopped.current?'stopped':'error'});}if(!stopped.current)setError(String(e));}
    finally{if(jobId.current)await api('/api/opex/stop',{id:jobId.current}).catch(e=>setError('Terminal stop not confirmed: '+String(e)));await cancelPending.current?.catch(()=>{});cancelPending.current=null;operation.current=false;setBusy(false);onActivity(false);controller.current=null;jobId.current='';setPhase('');setStream('');}
  }
  async function connect(id:string){
    const path=folder.trim();if(!path)throw Error('Enter the path to your project folder on this USB.');
    setPhase('Opening project');const data=await api('/api/opex/tree',{folder:path});
    if(stopped.current)return [];
    setFiles(data.files);setConnected(path);setTruncated(!!data.truncated);patch(id,{folder:path});return data.files as typeof files;
  }
  async function read(id:string,path:string){const result=await api('/api/opex/action',{folder:current(id).folder,action:'read',path});record(id,{kind:'read',path,text:result.exists===false?'File does not exist yet.':result.text});setPreview({path,text:result.text});return result;}
  async function advance(id:string,listing:typeof files){
    patch(id,{status:'working'});
    for(let step=0;step<8&&!stopped.current;step++){
      setPhase(`Opex is thinking · step ${step+1}`);setStream('');controller.current=new AbortController();
      const answer=await ask(workPrompt(current(id),listing.filter(f=>!f.directory).map(f=>f.path),instructions),controller.current.signal,text=>{if(current(id).strategy==='plan')setStream(text);});
      controller.current=null;if(stopped.current)return;
      if(current(id).strategy==='plan'){record(id,{kind:'assistant',text:answer});patch(id,{status:'done'});return;}
      let parsed:unknown;try{parsed=JSON.parse(answer.replace(/^\s*```(?:json)?\s*/, '').replace(/\s*```\s*$/, ''));}catch{throw Error('Opex did not return a valid action. Try a clearer prompt or a stronger coding model.');}
      const {proposal:valid}=await api('/api/opex/validate',{folder:current(id).folder,proposal:parsed});
      if(stopped.current)return;
      const next=valid as WorkProposal;
      if('answer' in next){record(id,{kind:'assistant',text:next.answer});patch(id,{status:'done'});return;}
      if(next.action==='read'){setPhase(`Reading · ${next.path}`);await read(id,next.path);continue;}
      if(next.action==='write'){
        setPhase(`Checking change · ${next.path}`);
        const previous=current(id).events.filter(e=>e.kind==='read'&&e.path===next.path).at(-1);
        const result=await api('/api/opex/action',{folder:current(id).folder,action:'read',path:next.path});
        const text=result.exists===false?'File does not exist yet.':result.text;
        if(!previous||previous.text!==text){record(id,{kind:'read',path:next.path,text});continue;}
        next.base=result.text;setPanel('changes');
      }else setPanel('terminal');
      if(stopped.current)return;
      setProposal(next);patch(id,{status:'approval'});return;
    }
    patch(id,{status:'stopped'});if(!stopped.current)record(id,{kind:'notice',text:'Eight steps completed. Review the results and choose Continue task to proceed.'});
  }
  async function submit(){
    if(!task||!task.draft.trim()||locked||proposal)return;
    const id=task.id,text=task.draft.trim();
    await operationRun(async()=>{let listing=files;if(connected!==folder.trim())listing=await connect(id);if(stopped.current)return;
      record(id,{kind:'user',text});patch(id,{draft:'',title:current(id).title==='New task'?text.slice(0,65):current(id).title});await advance(id,listing);
    });
  }
  async function approve(){
    if(!task||!proposal||'answer' in proposal||locked)return;
    const id=task.id,action=proposal;
    await operationRun(async()=>{
      setProposal(null);patch(id,{status:'working'});
      if(action.action==='write'){
        setPhase('Saving change');const result=await api('/api/opex/action',{...action,folder:current(id).folder,approved:true});
        const entry=record(id,{kind:'write',path:action.path,text:'Change saved',before:action.base,after:action.text,backup:result.backup});setSelectedChange(entry.id);
        if(!files.some(f=>f.path===action.path))setFiles(v=>[...v,{path:action.path,directory:false}]);
      }else if(action.action==='run'){
        setPhase('Terminal running');setLiveOutput('');
        const started=await api('/api/opex/run',{...action,folder:current(id).folder,approved:true});jobId.current=started.id;
        if(stopped.current)await api('/api/opex/stop',{id:started.id});
        let result;
        do{result=await api('/api/opex/job',{id:started.id});setLiveOutput(result.output||'');if(result.status==='running')await new Promise(r=>setTimeout(r,500));}while(result.status==='running');
        jobId.current='';if(result.error)throw Error(result.error);
        record(id,{kind:'run',command:action.command,exitCode:result.exit_code,text:(result.output||'(No output)')+(result.cancelled?'\nCommando gestopt.':result.timed_out?'\nTijdslimiet bereikt (60 seconden).':'')});
        if(result.cancelled||result.timed_out){patch(id,{status:'stopped'});return;}
      }
      if(stopped.current){patch(id,{status:'stopped'});return;}
      await advance(id,files);
    });
  }
  async function stop(){stopped.current=true;const generating=!!controller.current;controller.current?.abort();setPhase('Stopping…');
    const cancel=async()=>{if(jobId.current)await api('/api/opex/stop',{id:jobId.current});if(generating)await api('/api/models/cancel',{});};
    cancelPending.current=cancel();
    try{await cancelPending.current;}catch(e){setError('Stop request failed: '+String(e));}
    if(task)patch(task.id,{status:'stopped'});
  }
  function reject(){if(!task)return;setProposal(null);record(task.id,{kind:'notice',text:'Proposal rejected by the user. Waiting for a new request.'});patch(task.id,{status:'stopped'});}
  return <section className="ow-shell" aria-label="Opex Work">
    <aside className="ow-tasks" aria-label="Opex tasks">
      <div className="ow-brand"><Code2 size={21}/><strong>Opex</strong><span>Work</span></div>
      <button className="ow-new" disabled={locked} onClick={newTask}><Plus size={16}/>New task</button>
      <label className="ow-search"><Search size={14}/><input aria-label="Search tasks" placeholder="Search tasks…" value={query} onChange={e=>setQuery(e.target.value)}/></label>
      <p className="ow-label">On this USB</p>
      <div className="ow-task-list">{state.tasks.filter(t=>(t.title+' '+t.folder).toLowerCase().includes(query.toLowerCase())).map(t=><button key={t.id} disabled={locked} aria-current={t.id===state.active?'page':undefined} onClick={()=>switchTask(t.id)} className="ow-task"><span className="ow-task-title">{t.title}</span><span>{t.folder.split(/[\\/]/).filter(Boolean).at(-1)||'No project'} · {statusName[t.status==='working'&&!busy?'stopped':t.status]}</span></button>)}{!state.tasks.length&&<p className="ow-muted p-3">Create a task to work on a project.</p>}</div>
      <div className="ow-sidebar-note">Tasks and results are saved on your USB.</div>
    </aside>
    <div className="ow-main">
      <div className="ow-topline"><div><span className="ow-muted">Opex / </span><strong>{task?.title||'Your next project'}</strong></div><span className="ow-status">{busy?<LoaderCircle size={13} className="animate-spin"/>:<span className="ow-dot"/>}{task?statusName[task.status==='working'&&!busy?'stopped':task.status]:'Ready'}</span></div>
      {!task?<div className="ow-welcome"><Code2 size={34}/><h1>What shall we build?</h1><p>Work on your code, investigate a bug, or start with a plan.</p><button className="ow-primary" onClick={newTask} disabled={locked}><Plus size={16}/>Start a task</button><div className="ow-starters">{['Fix a bug','Build a feature','Understand a project'].map(text=><button key={text} disabled={locked} onClick={()=>{newTask();const id=latest.current.active;if(id)patch(id,{draft:text+': '});}}>{text}<ChevronRight size={15}/></button>)}</div></div>:<>
        <div className="ow-project"><FolderOpen size={16}/><input aria-label="Work project folder" disabled={locked||!!proposal||task.events.length>0} value={folder} onChange={e=>{setFolder(e.target.value);setConnected('');}} placeholder="Project folder on this USB; copy its path from File Explorer"/><button disabled={locked||!!proposal||!folder.trim()} onClick={()=>operationRun(()=>connect(task.id).then(()=>{}))}>{connected===folder.trim()?'Refresh':'Open project'}</button></div>
        <div className="ow-conversation" aria-label="Task timeline">
          {task.events.length===0&&<div className="ow-task-empty"><h2>From idea to working code.</h2><p>Open your project folder and describe what Opex should do.</p><p className="ow-muted">Work reads project files. Review changes and terminal commands before they run.</p></div>}
          {task.events.map(e=><div key={e.id} className={'ow-event ow-event-'+e.kind}>{e.kind==='user'?<div className="ow-user">{e.text}</div>:e.kind==='assistant'?<div className="ow-answer"><div className="ow-event-label"><Code2 size={16}/>Opex</div><CodeContent text={e.text}/></div>:['read','write','run'].includes(e.kind)?<details className="ow-tool"><summary><span>{e.kind==='read'?<FileText size={15}/>:e.kind==='write'?<Check size={15}/>:<Terminal size={15}/>}</span><span>{e.kind==='read'?'File read':e.kind==='write'?'File changed':'Terminal'}<b>{e.path||e.command}</b></span>{e.kind==='run'&&<small>exit {e.exitCode??'—'}</small>}</summary><pre>{e.kind==='write'?`Backup: ${e.backup}`:e.text}</pre>{e.kind==='write'&&<button onClick={()=>{setPanel('changes');setSelectedChange(e.id);}}>View diff</button>}</details>:<p className={e.kind==='error'?'ow-error':'ow-notice'}>{e.text}</p>}</div>)}
          {busy&&<div className="ow-working" role="status"><LoaderCircle size={15} className="animate-spin"/>{phase}</div>}{stream&&<div className="ow-stream">{stream}</div>}
          {proposal&&!('answer' in proposal)&&<div className="ow-approval" aria-label="Review action"><div className="ow-event-label">Your approval is needed</div><h3>{proposal.action==='write'?`Change ${proposal.path}`:'Run terminal command'}</h3>{proposal.action==='run'?<><pre>{proposal.command}</pre><p>PowerShell runs with your Windows permissions, including outside the project folder. Maximum 60 seconds.</p></>:<><DiffView before={proposal.base||''} after={proposal.text}/><p>Saving creates a backup. Changes are rejected if the original file has changed.</p></>}<div className="ow-actions"><button className="ow-primary" disabled={locked} onClick={approve}>{proposal.action==='run'?'Approve and run':'Approve and save'}</button><button className="ow-secondary" disabled={locked} onClick={reject}>Reject</button></div></div>}
          <div ref={end}/>
        </div>
        <div className="ow-composer-wrap">{error&&<p role="alert" className="ow-error">{error}</p>}
          <div className="ow-composer"><textarea aria-label="Work prompt" rows={3} maxLength={3000} value={task.draft} disabled={locked||!!proposal} onChange={e=>patch(task.id,{draft:e.target.value})} onKeyDown={e=>{if(enterToSend&&e.key==='Enter'&&!e.shiftKey&&!e.nativeEvent.isComposing){e.preventDefault();void submit();}}} placeholder={proposal?'Review the proposal above first…':'Describe a task, ask a follow-up, or provide guidance…'}/>
            <div className="ow-composer-bottom"><select aria-label="Work mode" disabled={locked||!!proposal} value={task.strategy} onChange={e=>patch(task.id,{strategy:e.target.value as WorkTask['strategy']})}><option value="act">Work · execute</option><option value="plan">Plan · discuss only</option></select><select aria-label="Work model" value={model} disabled={locked||!!proposal} onChange={e=>onModel(e.target.value)}>{models.map(m=><option key={m.id} value={m.id}>{m.name}{m.remote?' · API':''}</option>)}</select><div className="ow-spacer"/>{busy?<button className="ow-send" aria-label="Stop Opex" onClick={stop}><Square size={15}/></button>:<button className="ow-send" aria-label="Send Work prompt" disabled={locked||!!proposal||!task.draft.trim()||!folder.trim()} onClick={submit}><ArrowUp size={18}/></button>}</div>
          </div><div className="ow-composer-note"><span>{remote?'Project context is shared with your API provider.':'Your selected model handles this task.'}</span>{!busy&&!proposal&&task.events.length>0&&task.status!=='done'&&<button disabled={disabled} onClick={()=>operationRun(async()=>{const listing=connected===folder?files:await connect(task.id);if(!stopped.current)await advance(task.id,listing);})}>Continue task →</button>}</div>
        </div>
      </>}
    </div>
    {task&&<aside className="ow-inspector" aria-label="Project inspector"><div className="ow-tabs" role="tablist" aria-label="Project panels">{(['files','changes','terminal'] as const).map(key=><button key={key} role="tab" aria-selected={panel===key} onClick={()=>setPanel(key)}>{key==='files'?'Files':key==='changes'?`Changes ${changes.length}`:'Terminal'}</button>)}</div>
      <div className="ow-inspector-body">{panel==='files'?<><label className="ow-search"><Search size={13}/><input aria-label="Search project files" placeholder="Search files…" value={fileQuery} onChange={e=>setFileQuery(e.target.value)}/></label>{!connected&&<p className="ow-muted">Open the project to view files.</p>}{truncated&&<p className="ow-muted">First 1,000 items, up to 6 subfolder levels.</p>}<div className="ow-files">{files.filter(f=>f.path.toLowerCase().includes(fileQuery.toLowerCase())).map(f=><button key={f.path} disabled={locked||f.directory||!!proposal} title={f.path} onClick={()=>operationRun(async()=>{setPhase('Opening file');const result=await api('/api/opex/action',{folder:task.folder,action:'read',path:f.path});setPreview({path:f.path,text:result.text});})}>{f.directory?<Folder size={14}/>:<FileText size={14}/>}<span>{f.path}</span></button>)}</div>{preview&&<div className="ow-file-preview"><div><strong>{preview.path}</strong><button aria-label="Close file preview" onClick={()=>setPreview(null)}><X size={14}/></button></div><pre>{preview.text||'(Empty file)'}</pre></div>}</>:panel==='changes'?<>{changes.length===0?<p className="ow-muted">Saved changes appear here. New proposals appear in the timeline.</p>:<><select className={field} aria-label="View change" value={change?.id} onChange={e=>setSelectedChange(e.target.value)}>{changes.map((e,i)=><option key={e.id} value={e.id}>{i+1}. {e.path}</option>)}</select>{change&&<><DiffView before={change.before||''} after={change.after||''}/><p className="ow-muted break-all">Backup: {change.backup}</p></>}</>}</>:<>{busy&&phase==='Terminal running'&&<pre aria-label="Live terminal output" className="ow-terminal">{liveOutput||'Waiting for output…'}</pre>}{commands.length===0&&!liveOutput&&<p className="ow-muted">Approved commands and their output appear here.</p>}{commands.map(e=><div key={e.id} className="ow-terminal-entry"><p><Terminal size={13}/>{e.command}</p><pre>{e.text}</pre><span>Exit code {e.exitCode??'—'}</span></div>)}</>}</div>
    </aside>}
  </section>;
}
