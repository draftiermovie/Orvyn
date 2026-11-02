use std::{env,path::PathBuf,process::Command};
fn main() {
    println!("cargo:rerun-if-changed=assets/orvyn.ico");
    if env::var("CARGO_CFG_TARGET_OS").unwrap()!="windows" {return;}
    let manifest=PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap());
    let out=PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let rc=out.join("orvyn.rc");
    std::fs::write(&rc,format!("1 ICON \"{}\"\n",manifest.join("assets/orvyn.ico").display().to_string().replace('\\',"/"))).unwrap();
    let resource=out.join("orvyn.o");
    let compiler=manifest.join("../../tools/llvm-mingw-20260922-msvcrt-x86_64/bin/llvm-windres.exe");
    assert!(Command::new(compiler).args(["-i"]).arg(rc).args(["-o"]).arg(&resource).args(["-O","coff"]).status().unwrap().success(),"Icon resource failed");
    println!("cargo:rustc-link-arg={}",resource.display());
}
