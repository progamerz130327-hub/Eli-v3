const express = require("express");
const app = express();
app.use(express.json());

const chats = new Map();

app.post("/chat", (req, res) => {
  const message = String(req.body.message || "");
  // Replace this with your chosen AI provider on the SERVER.
  res.json({
    reply: `Eli server received: ${message}`
  });
});

app.post("/sync/push", (req, res) => {
  const deviceId = String(req.body.deviceId || "unknown");
  chats.set(deviceId, req.body.messages || []);
  res.json({ok: true});
});

app.get("/sync/pull", (req, res) => {
  const deviceId = String(req.query.deviceId || "unknown");
  res.json({messages: chats.get(deviceId) || []});
});

app.listen(process.env.PORT || 3000, () => {
  console.log("Eli server running");
});
