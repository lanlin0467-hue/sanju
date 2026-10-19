// Explicit manual smoke check: at most four paid completions (two bounded workflows).
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { liveCompletion, writer } from "../src/lib/beta/model";
import { styles } from "../src/lib/beta/contracts";

await mkdir(".local",{recursive:true,mode:0o700});
const input={scene:"这是三句应用的图标，请为这个简洁的图形写配文",mood:"期待",image:"data:image/png;base64,"+(await readFile("public/icons/icon-192.png")).toString("base64")};
const completion=liveCompletion(); const rawOutputs:string[]=[];
const write=writer(async (...args)=>{const raw=await completion(...args);rawOutputs.push(raw);await writeFile(".local/model-smoke-raw.json",JSON.stringify(rawOutputs,null,2),{mode:0o600});return raw;});
const start=Date.now();
try{
 const lines=await write(input,styles,[]);
 const replacement=await write(input,["cool"],[lines.find(line=>line.style==="cool")!.text]);
 await writeFile(".local/model-smoke.json",JSON.stringify({timestamp:new Date().toISOString(),model:process.env.SANJU_MODEL_ID??"qwen/qwen3.7-flash",imageUsed:true,lines,replacement,durationMs:Date.now()-start},null,2),{mode:0o600});
 console.log(JSON.stringify({ok:true,lines,replacement,durationMs:Date.now()-start}));
}catch(error){console.error(JSON.stringify({ok:false,error:error instanceof Error?error.message:"model_failed",durationMs:Date.now()-start}));process.exitCode=1;}
