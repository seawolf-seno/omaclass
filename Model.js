// OmaClass panel logic, kept free of QML so node can test it.

var MAX_TEXT = 500

// A made-up class for showing the panel to other teachers when no student
// computers are reachable. Names are fictional; nothing here is real data.
function sampleClass() {
  var names = ["Ava", "Ben", "Chloe", "Diego", "Ellie", "Finn", "Grace", "Hugo",
               "Isla", "Jonah", "Kai", "Lena"]
  var computers = []
  for (var i = 0; i < names.length; i++) {
    computers.push({ name: names[i], host: "sample-" + (i + 1) })
  }
  return { name: "Period 3 · Intro to CS", computers: computers, sample: true }
}

// Online map for the sample class: everyone but two, so the panel shows
// both states.
function sampleStatus(cls) {
  var status = {}
  for (var i = 0; i < cls.computers.length; i++) {
    status[cls.computers[i].host] = !(i === 4 || i === 9)
  }
  return status
}

function parseJson(text) {
  try {
    var value = JSON.parse(String(text || ""))
    return value && typeof value === "object" ? value : null
  } catch (e) {
    return null
  }
}

function initials(name) {
  var parts = String(name || "").trim().split(/[\s._-]+/).filter(function(p) { return p !== "" })
  if (parts.length === 0) return "?"
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase()
}

function onlineHosts(cls, status) {
  if (!cls) return []
  var out = []
  for (var i = 0; i < cls.computers.length; i++) {
    var host = cls.computers[i].host
    if (status && status[host] === true) out.push(host)
  }
  return out
}

function allHosts(cls) {
  if (!cls) return []
  return cls.computers.map(function(c) { return c.host })
}

// "https://" is added when a teacher types a bare domain. Anything that is
// not plain http(s) is refused.
function normalizeUrl(text) {
  var value = String(text || "").trim()
  if (value === "" || value.length > MAX_TEXT || /\s/.test(value)) return ""
  if (!/^[a-z][a-z0-9+.-]*:/i.test(value)) value = "https://" + value
  if (!/^https?:\/\/[^\/\s]+/i.test(value)) return ""
  return value
}

function messageArgs(text) {
  var value = String(text || "").trim()
  if (value === "") return ""
  return JSON.stringify({ title: "Message from your teacher", text: value.slice(0, MAX_TEXT) })
}

function websiteArgs(url) {
  var value = normalizeUrl(url)
  return value === "" ? "" : JSON.stringify({ websiteUrls: value })
}

function countLabel(n, one, many) {
  return n === 1 ? one.replace("%1", n) : many.replace("%1", n)
}

// One line of feedback after an action, so the teacher knows it landed.
function resultText(verb, done, failed, sample) {
  var text = verb + " " + countLabel(done, "%1 computer", "%1 computers")
  if (failed > 0) text += " · " + failed + " didn't respond"
  if (sample) text += " (sample)"
  return text
}

if (typeof module !== "undefined") {
  module.exports = {
    sampleClass: sampleClass,
    sampleStatus: sampleStatus,
    parseJson: parseJson,
    initials: initials,
    onlineHosts: onlineHosts,
    allHosts: allHosts,
    normalizeUrl: normalizeUrl,
    messageArgs: messageArgs,
    websiteArgs: websiteArgs,
    resultText: resultText
  }
}
