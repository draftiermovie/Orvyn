// Consume actual SSE chunks; ordinary JSON remains supported for older runtimes.
export async function chatRequest(body:unknown,signal:AbortSignal,onText?:(text:string)=>void){
  const response=await fetch('/api/chat-stream',{method:'POST',signal,headers:{'Content-Type':'application/json'},body:JSON.stringify({...body as object,stream:true})});
  if(!response.headers.get('content-type')?.includes('text/event-stream')){
    const data=await response.json();if(!response.ok||data.error)throw new Error(typeof data.error==='string'?data.error:data.error?.message||'Model request failed');onText?.(data.choices?.[0]?.message?.content||'');return data;
  }
  if(!response.ok||!response.body)throw new Error('Streaming response unavailable');
  const reader=response.body.getReader(),decoder=new TextDecoder();let pending='',content='',usage:unknown;let done=false;
  function event(line:string){if(done||!line.startsWith('data:'))return;const value=line.slice(5).trim();if(value==='[DONE]'){done=true;return;}if(!value)return;const data=JSON.parse(value);if(data.error)throw new Error(typeof data.error==='string'?data.error:data.error.message);const delta=data.choices?.[0]?.delta?.content;if(delta){content+=delta;onText?.(content);}if(data.usage)usage=data.usage;}
  try{while(true){const chunk=await reader.read();pending+=decoder.decode(chunk.value,{stream:!chunk.done});const lines=pending.split('\n');pending=lines.pop()||'';for(const line of lines)event(line.trimEnd());if(done||chunk.done)break;}if(!done&&pending)event(pending);if(!done)throw new Error('Connection interrupted; response may be incomplete.');}
  finally{try{await reader.cancel();}catch{/* Preserve the original stream error when cancellation fails. */}finally{reader.releaseLock();}}
  return {choices:[{message:{content}}],usage};
}
