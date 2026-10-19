import { connection } from "next/server";
import { health } from "@/lib/beta/server";
export async function GET() { await connection(); return health(); }
