import http from "node:http";

const PORT = Number(process.env.PORT || 3000);
const API_KEY = process.env.OPENAI_API_KEY || "";
const MODEL = process.env.OPENAI_MODEL || "gpt-5.6-luna";

function send(res, status, body) {
  res.writeHead(status, {"Content-Type":"application/json; charset=utf-8"});
  res.end(JSON.stringify(body));
}

async function callOpenAI(message, language, memory) {
  if (!API_KEY) throw new Error("OPENAI_API_KEY is not configured");
  const system = [
    "You are AI Robot PRO v2, a friendly personal AI assistant.",
    "Respond naturally and helpfully.",
    `Preferred language: ${language === "ar" ? "Arabic" : "English"}.`,
    "Use the user's saved memory when relevant, but do not invent facts.",
    `Memory: ${JSON.stringify(memory ?? [])}`
  ].join("\n");

  const r = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: MODEL,
      input: [
        { role: "system", content: [{ type: "input_text", text: system }] },
        { role: "user", content: [{ type: "input_text", text: String(message ?? "") }] }
      ]
    })
  });

  const data = await r.json();
  if (!r.ok) {
    throw new Error(data?.error?.message || `OpenAI HTTP ${r.status}`);
  }

  const text =
    data?.output?.flatMap?.(item => item?.content ?? [])
      ?.find?.(c => c?.type === "output_text")?.text
    ?? data?.output_text
    ?? "";

  if (!text) throw new Error("No output text returned by AI service");
  return text;
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    return send(res, 200, {ok:true, service:"AI Robot PRO v2"});
  }

  if (req.method === "POST" && req.url === "/chat") {
    let body = "";
    req.on("data", chunk => body += chunk);
    req.on("end", async () => {
      try {
        const input = JSON.parse(body || "{}");
        const answer = await callOpenAI(input.message, input.language, input.memory);
        send(res, 200, {answer});
      } catch (e) {
        send(res, 500, {error: e?.message || "AI service error"});
      }
    });
    return;
  }

  send(res, 404, {error:"Not found"});
});

server.listen(PORT, () => {
  console.log(`AI Robot server listening on port ${PORT}`);
});
