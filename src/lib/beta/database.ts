import { Pool } from "pg";

export interface SQL {
  query<T = Record<string, unknown>>(text: string, values?: unknown[]): Promise<{ rows: T[] }>;
}
export interface Database extends SQL {
  transaction<T>(work: (sql: SQL) => Promise<T>): Promise<T>;
}
let pool: Pool | undefined;
export function database(): Database {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error("database_not_configured");
  if (!pool) {
    pool = new Pool({ connectionString, max: 4, connectionTimeoutMillis: 8000, idleTimeoutMillis: 20_000, statement_timeout: 10_000 });
    pool.on("error", () => { /* Never log credentials. */ });
  }
  const active = pool;
  return {
    async query<T>(text: string, values: unknown[] = []) { return { rows: (await active.query(text, values)).rows as T[] }; },
    async transaction<T>(work: (sql: SQL) => Promise<T>) {
      const client = await active.connect();
      try {
        await client.query("BEGIN");
        const value = await work({ async query<R>(text: string, values: unknown[] = []) { return { rows: (await client.query(text, values)).rows as R[] }; } });
        await client.query("COMMIT"); return value;
      } catch (error) { await client.query("ROLLBACK"); throw error; }
      finally { client.release(); }
    },
  };
}
