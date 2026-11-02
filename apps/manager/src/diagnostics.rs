use serde_json::{json,Value};
use std::{sync::Mutex,time::Instant};

pub struct Startup { start:Instant, state:Mutex<State> }
struct State { last:u64, phases:Vec<Value>, complete:bool, frontend:Value }
impl Startup {
    pub fn new()->Self{Self{start:Instant::now(),state:Mutex::new(State{last:0,phases:vec![],complete:false,frontend:Value::Null})}}
    pub fn mark(&self,id:&str,label:&str){
        let elapsed=self.start.elapsed().as_millis() as u64;
        if let Ok(mut state)=self.state.lock(){
            if state.complete{return;}
            let duration=elapsed.saturating_sub(state.last);
            state.phases.push(json!({"id":id,"label":label,"duration_ms":duration,"end_ms":elapsed}));state.last=elapsed;
        }
    }
    pub fn ready(&self,frontend:&Value){
        self.mark("interface","Interface en gesprekken laden");
        if let Ok(mut state)=self.state.lock(){state.complete=true;state.frontend=frontend.clone();}
    }
    pub fn snapshot(&self)->Value{
        let state=self.state.lock().unwrap();
        json!({"complete":state.complete,"total_ms":if state.complete{state.last}else{self.start.elapsed().as_millis() as u64},
            "phases":state.phases,"frontend":state.frontend,
            "note":"Vanaf het starten van de desktopcode tot het invoerveld is getoond. Het laden van het executable door Windows valt buiten deze meting. Browserdetails overlappen met de fasen en worden niet opgeteld."})
    }
}
