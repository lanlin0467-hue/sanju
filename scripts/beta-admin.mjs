import { Pool } from "pg";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { mkdir, writeFile, readFile } from "node:fs/promises";
import nextEnv from "@next/env";
const { loadEnvConfig } = nextEnv;
loadEnvConfig(process.cwd());
if (!process.env.DATABASE_URL) { console.error("DATABASE_URL is missing. Pull production variables into .env.beta.local first."); process.exit(1); }
const pool = new Pool({ connectionString: process.env.DATABASE_URL, max:1, connectionTimeoutMillis:10000 });
const hash = value => createHash("sha256").update(value).digest("hex");
try {
  const [command, argument="tester"] = process.argv.slice(2);
  if (command === "migrate") {
    await pool.query(await readFile("db/migrations/001_beta.sql","utf8"));
    console.log("Beta database migration applied.");
  } else if (command === "invite") {
    const code=randomBytes(18).toString("base64url"); const id=randomUUID();
    await pool.query("INSERT INTO sanju_beta.testers(id,code_hash,label,expires_at) VALUES($1,$2,$3,now()+interval '30 days')",[id,hash(code),argument.slice(0,80)]);
    await mkdir(".local",{recursive:true,mode:0o700});
    const path=`.local/invite-${id}.txt`;
    await writeFile(path,`测试者标识：${id}\n备注：${argument.slice(0,80)}\n邀请码：${code}\n有效期：30 天\n请单独发给受邀测试者；同码共享额度。\n`,{mode:0o600});
    console.log(`Invitation saved to ${path}; the plain code is not stored in the database.`);
  } else if(command === "revoke") {
    if(!/^[\da-f-]{36}$/i.test(argument)) throw new Error("tester_id_required");
    await pool.query("UPDATE sanju_beta.testers SET revoked=true WHERE id=$1",[argument]);
    await pool.query("DELETE FROM sanju_beta.sessions WHERE tester_id=$1",[argument]);
    console.log("Tester access revoked.");
  } else if(command === "purge") {
    if(!/^[\da-f-]{36}$/i.test(argument)) throw new Error("tester_id_required");
    // Keep usage and budget counters, so data deletion cannot reset paid quotas.
    const client=await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("SELECT id FROM sanju_beta.testers WHERE id=$1 FOR UPDATE",[argument]);
      const active=await client.query("SELECT id FROM sanju_beta.jobs WHERE tester_id=$1 AND status='processing' AND lease_until>now()",[argument]);
      if(active.rows.length) throw new Error("wait_for_active_request");
      for(const table of ["feedback","jobs","creations"]) await client.query(`DELETE FROM sanju_beta.${table} WHERE tester_id=$1`,[argument]);
      await client.query("COMMIT"); console.log("Server content removed; quotas preserved.");
    } catch(error) {await client.query("ROLLBACK"); throw error;} finally {client.release();}
  } else if(command === "status") {
    const result=await pool.query("SELECT (SELECT count(*) FROM sanju_beta.testers WHERE NOT revoked AND expires_at>now()) AS testers,(SELECT count(*) FROM sanju_beta.jobs WHERE status='processing') AS pending");
    console.log(result.rows[0]);
  } else throw new Error("Use migrate, invite <label>, revoke <tester-id>, purge <tester-id>, or status.");
} catch(error) {console.error(error.code || "beta_admin_failed"); process.exitCode=1;} finally {await pool.end();}
