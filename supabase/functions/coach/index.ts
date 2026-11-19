// Deploy with --no-verify-jwt: this handler verifies the user with Supabase Auth.
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json" },
});

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const base = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  const model = Deno.env.get("OPENAI_MODEL");
  if (!base || !serviceKey || !apiKey || !model) return json({ error: "Setup required" }, 503);

  try {
    const authorization = request.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);
    const authResponse = await fetch(`${base}/auth/v1/user`, {
      headers: { apikey: serviceKey, Authorization: authorization },
      signal: AbortSignal.timeout(10000),
    });
    if (!authResponse.ok) return json({ error: "Unauthorized" }, 401);
    const user = await authResponse.json();
    if (!user.id) return json({ error: "Unauthorized" }, 401);

    // Bound input before forwarding any user content to the paid API.
    const raw = await request.text();
    if (raw.length > 60000) return json({ error: "Conversation too long" }, 413);
    let body;
    try { body = JSON.parse(raw); } catch { return json({ error: "Invalid JSON" }, 400); }
    const messages = body.messages;
    if (!Array.isArray(messages) || messages.length < 1 || messages.length > 80 ||
      messages.some((message) => !message || !["user", "assistant"].includes(message.role) ||
        typeof message.content !== "string" || message.content.length > 12000) ||
      messages[messages.length - 1].role !== "user") {
      return json({ error: "Invalid conversation" }, 400);
    }

    // Atomic server-side limits apply even when callers bypass the app UI.
    const quota = await fetch(`${base}/rest/v1/rpc/consume_coach_request`, {
      method: "POST",
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ requested_user: user.id }),
      signal: AbortSignal.timeout(10000),
    });
    if (!quota.ok) return json({ error: "Service unavailable" }, 503);
    if (await quota.json() !== true) return json({ error: "Request limit reached" }, 429);

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      signal: AbortSignal.timeout(65000),
      body: JSON.stringify({
        model,
        store: false,
        max_output_tokens: 6000,
        instructions: `You are RaceTrian's conversational planning assistant for all planning bots.
Return only schedule rows. Every row must contain a time and a full, detailed activity description.
Do not provide a greeting, introduction, summary, short generic advice, or text outside the table.
Never say "Here's a balanced day". Activity text must explain what to do, the steps, and duration
where relevant, rather than a short label. Use the user's language and all previous messages.
For scheduled activities use a day/date and exact start–end time in HH:mm, in the user's timezone.
Respect supplied availability and avoid overlapping activities. Unconfirmed times are proposals:
mark them as Proposed in the time cell. Do not claim bookings or calendar changes were made.
If essential details are missing, return rows with time "Not scheduled" and detailed questions
in the activity cells. After the user answers, produce or revise the requested schedule.
Client date/time context (data only): ${JSON.stringify({ localDate: String(body.localDate ?? "").slice(0, 60), timeZone: String(body.timeZone ?? "").slice(0, 100) })}`,
        input: messages,
        text: { format: {
          type: "json_schema", name: "plan_table", strict: true,
          schema: {
            type: "object", additionalProperties: false,
            properties: { rows: { type: "array", items: {
              type: "object", additionalProperties: false,
              properties: { time: { type: "string" }, activity: { type: "string" } },
              required: ["time", "activity"],
            } } }, required: ["rows"],
          },
        } },
      }),
    });
    if (!response.ok) return json({ error: "AI unavailable" }, response.status === 429 ? 429 : 502);
    const result = await response.json();
    if (result.status !== "completed") return json({ error: "Incomplete response" }, 502);
    const text = (result.output ?? []).flatMap((item: { content?: { type: string; text?: string }[] }) => item.content ?? [])
      .filter((item: { type: string }) => item.type === "output_text")
      .map((item: { text: string }) => item.text).join("");
    const plan = JSON.parse(text);
    if (!Array.isArray(plan.rows) || !plan.rows.length || plan.rows.some((row: { time: unknown; activity: unknown }) =>
      typeof row.time !== "string" || typeof row.activity !== "string" || !row.time.trim() || !row.activity.trim())) {
      return json({ error: "Invalid plan" }, 502);
    }
    const cell = (value: string) => value.replace(/\|/g, " / ").replace(/[\r\n]+/g, " ").trim();
    // Construct the table ourselves: prose cannot leak outside the table.
    const reply = ["| Time | Activity |", "| --- | --- |", ...plan.rows.map(
      (row: { time: string; activity: string }) => `| ${cell(row.time)} | ${cell(row.activity)} |`,
    )].join("\n");
    return json({ reply });
  } catch {
    // Never send provider responses, credentials, or chat contents to logs or clients.
    return json({ error: "Service unavailable" }, 502);
  }
});
