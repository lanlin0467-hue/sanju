import { betaEnabled, invoke } from "@/lib/beta/server";
import { createNativeGenerationAPI } from "@/lib/nativeGeneration";

export const maxDuration = 60;

const developmentGlobal = globalThis as typeof globalThis & { sanjuNativeAPI?: ReturnType<typeof createNativeGenerationAPI> };
const api = developmentGlobal.sanjuNativeAPI ??= createNativeGenerationAPI();
export const GET = (request: Request) => betaEnabled() ? invoke("GET", request) : api.GET(request);
export const POST = (request: Request) => betaEnabled() ? invoke("POST", request) : api.POST(request);
