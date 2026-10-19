import { database } from "@/lib/beta/database";
import { cleanup, validCronAuthorization } from "@/lib/beta/maintenance";
import { json, problem } from "@/lib/beta/contracts";
export async function GET(request: Request) {
  if (!validCronAuthorization(request.headers.get("authorization"))) return json({ error: "unauthorized" },401);
  try { await cleanup(database()); return json({ ok:true }); } catch(error) { return problem(error); }
}
