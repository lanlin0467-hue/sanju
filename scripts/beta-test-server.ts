// Loopback-only HTTP fixture for iOS UI tests. This never calls a model provider.
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { PGlite } from "@electric-sql/pglite";
import { createBetaAPI } from "../src/lib/beta/api";
import { digest } from "../src/lib/beta/contracts";
import type { Database, SQL } from "../src/lib/beta/database";
import { nativeSamples } from "../src/lib/nativeGeneration";

const pg=new PGlite(); await pg.exec(readFileSync("db/migrations/001_beta.sql","utf8"));
function adapter(client: Pick<PGlite,"query">): SQL { return { async query<T>(text:string,values:unknown[]=[]){return {rows:(await client.query(text,values)).rows as T[]};} }; }
const db: Database={...adapter(pg),transaction:work=>pg.transaction(tx=>work(adapter(tx as unknown as PGlite)))};
await db.query("INSERT INTO sanju_beta.testers(id,code_hash,label,expires_at) VALUES($1,$2,'UI fixture',now()+interval '1 day')",["00000000-0000-4000-8000-000000000001",digest("sanju-uitest-invite-for-local-only")]);
const api=createBetaAPI(db,async (_input,styles,previous)=>styles.map(style=>({style,text:nativeSamples[style].find(text=>!previous.includes(text))!})),{dailyCalls:200});
const server=createServer(async (incoming,outgoing)=>{
  try{
    const chunks:Buffer[]=[];let bytes=0;
    for await (const chunk of incoming){bytes+=chunk.length;if(bytes>750000){outgoing.writeHead(413).end();return;}chunks.push(chunk);}
    const method=incoming.method||"GET";
    const request=new Request(`http://127.0.0.1:3002${incoming.url}`,{method,headers:incoming.headers as HeadersInit,...(method==="POST"?{body:Buffer.concat(chunks)}:{})});
    const path=new URL(request.url).pathname;
    let response:Response;
    if(path.endsWith("sessions")) response=method==="POST"?await api.join(request):await api.signOut(request);
    else if(path.endsWith("feedback")) response=await api.feedback(request);
    else response=method==="POST"?await api.POST(request):await api.GET(request);
    outgoing.writeHead(response.status,Object.fromEntries(response.headers));outgoing.end(Buffer.from(await response.arrayBuffer()));
  }catch{outgoing.writeHead(500).end();}
});
server.listen(3002,"127.0.0.1",()=>console.log("Beta UI fixture ready on 127.0.0.1:3002 (fixed text; no paid model)"));
async function stop(){server.close();await pg.close();process.exit(0);}
process.on("SIGTERM",stop);process.on("SIGINT",stop);
