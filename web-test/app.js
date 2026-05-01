const STORAGE_KEY = "nirdist-test-console-settings-v1";

const presets = [
  {
    label: "Health Check",
    method: "GET",
    path: "/api/health",
    body: ""
  },
  {
    label: "List Profiles",
    method: "GET",
    path: "/api/social/profiles?excludeUserId=1",
    body: ""
  },
  {
    label: "Can Message",
    method: "GET",
    path: "/api/social/permissions/message?userId=1&otherUserId=2",
    body: ""
  },
  {
    label: "List Chat Rooms",
    method: "GET",
    path: "/api/chat/rooms?userId=1",
    body: ""
  },
  {
    label: "Phone Exchange",
    method: "POST",
    path: "/api/auth/phone/exchange",
    body: JSON.stringify({
      phoneNumber: "+9779800000000",
      fullName: "Test User"
    }, null, 2)
  }
];

const el = {
  baseUrl: document.getElementById("baseUrl"),
  bearerToken: document.getElementById("bearerToken"),
  saveSettings: document.getElementById("saveSettings"),
  checkHealth: document.getElementById("checkHealth"),
  settingsMsg: document.getElementById("settingsMsg"),
  presetButtons: document.getElementById("presetButtons"),
  method: document.getElementById("method"),
  path: document.getElementById("path"),
  body: document.getElementById("body"),
  sendRequest: document.getElementById("sendRequest"),
  clearBody: document.getElementById("clearBody"),
  responseMeta: document.getElementById("responseMeta"),
  responseOutput: document.getElementById("responseOutput")
};

function normalizeBaseUrl(url) {
  return (url || "").trim().replace(/\/+$/, "");
}

function loadSettings() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return;
    }

    const parsed = JSON.parse(raw);
    el.baseUrl.value = parsed.baseUrl || "https://nirdist-backend-uctd.onrender.com";
    el.bearerToken.value = parsed.bearerToken || "";
  } catch {
    el.baseUrl.value = "https://nirdist-backend-uctd.onrender.com";
  }
}

function saveSettings() {
  const settings = {
    baseUrl: normalizeBaseUrl(el.baseUrl.value),
    bearerToken: el.bearerToken.value.trim()
  };

  localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
  el.settingsMsg.textContent = "Settings saved.";
  el.settingsMsg.className = "note ok";
}

function renderPresets() {
  for (const preset of presets) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "btn preset";
    btn.textContent = `${preset.label} (${preset.method} ${preset.path})`;
    btn.addEventListener("click", () => {
      el.method.value = preset.method;
      el.path.value = preset.path;
      el.body.value = preset.body;
    });
    el.presetButtons.appendChild(btn);
  }
}

function setResponse(meta, output, isError = false) {
  el.responseMeta.textContent = meta;
  el.responseMeta.className = isError ? "meta err" : "meta ok";
  el.responseOutput.textContent = output;
}

async function sendRequest({ method, path, body }) {
  const baseUrl = normalizeBaseUrl(el.baseUrl.value);
  if (!baseUrl) {
    setResponse("Error", "Please enter Backend Base URL first.", true);
    return;
  }

  const fullUrl = `${baseUrl}${path.startsWith("/") ? path : `/${path}`}`;
  const headers = {
    Accept: "application/json"
  };

  const token = el.bearerToken.value.trim();
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const hasBody = ["POST", "PUT", "PATCH", "DELETE"].includes(method);
  let requestBody;
  if (hasBody && body.trim()) {
    headers["Content-Type"] = "application/json";
    requestBody = body;
  }

  const start = performance.now();

  try {
    const res = await fetch(fullUrl, {
      method,
      headers,
      body: requestBody
    });

    const contentType = res.headers.get("content-type") || "";
    let payload;

    if (contentType.includes("application/json")) {
      payload = JSON.stringify(await res.json(), null, 2);
    } else {
      payload = await res.text();
    }

    const ms = Math.round(performance.now() - start);
    setResponse(`HTTP ${res.status} ${res.statusText} in ${ms} ms`, payload || "(empty)", !res.ok);
  } catch (error) {
    setResponse("Network Error", String(error), true);
  }
}

el.saveSettings.addEventListener("click", saveSettings);

el.checkHealth.addEventListener("click", () => {
  sendRequest({ method: "GET", path: "/api/health", body: "" });
});

el.sendRequest.addEventListener("click", () => {
  sendRequest({
    method: el.method.value,
    path: el.path.value.trim(),
    body: el.body.value
  });
});

el.clearBody.addEventListener("click", () => {
  el.body.value = "";
});

loadSettings();
renderPresets();
if (!el.baseUrl.value) {
  el.baseUrl.value = "https://nirdist-backend-uctd.onrender.com";
}
