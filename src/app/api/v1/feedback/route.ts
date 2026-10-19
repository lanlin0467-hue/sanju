import { invoke } from "@/lib/beta/server";
export const POST = (request: Request) => invoke("feedback", request);
