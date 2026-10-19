import { invoke } from "@/lib/beta/server";
export const maxDuration = 30;
export const POST = (request: Request) => invoke("join", request);
export const DELETE = (request: Request) => invoke("signOut", request);
