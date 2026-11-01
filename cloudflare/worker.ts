import { Container } from "@cloudflare/containers";

interface Env {
  NAMELESS: DurableObjectNamespace<NamelessContainer>;
  R2_ACCOUNT_ID: string;
  R2_BUCKET_NAME: string;
  AWS_ACCESS_KEY_ID: string;
  AWS_SECRET_ACCESS_KEY: string;
}

export class NamelessContainer extends Container<Env> {
  defaultPort = 8080;
  requiredPorts = [8080];
  sleepAfter = "30m";
  enableInternet = true;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.envVars = {
      R2_ACCOUNT_ID: env.R2_ACCOUNT_ID,
      R2_BUCKET_NAME: env.R2_BUCKET_NAME,
      AWS_ACCESS_KEY_ID: env.AWS_ACCESS_KEY_ID,
      AWS_SECRET_ACCESS_KEY: env.AWS_SECRET_ACCESS_KEY,
    };
  }

  onStart() {
    console.log("NamelessMC container started");
  }

  onError(error: unknown) {
    console.error("NamelessMC container error", error);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/__health") {
      return Response.json({ ok: true, service: "namelessmc-cloudflare-container" });
    }

    const container = env.NAMELESS.getByName("nameless-production");
    await container.startAndWaitForPorts();
    return container.fetch(request);
  },
};
