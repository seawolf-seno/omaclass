const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

test("sample class is fictional and has online and offline students", () => {
  const cls = Model.sampleClass()
  assert.equal(cls.sample, true)
  assert.equal(cls.computers.length, 12)
  const status = Model.sampleStatus(cls)
  assert.equal(Model.onlineHosts(cls, status).length, 10)
  assert.ok(cls.computers.every(c => c.host.startsWith("sample-")))
})

test("initials", () => {
  assert.equal(Model.initials("Ava"), "AV")
  assert.equal(Model.initials("media-cart"), "MC")
  assert.equal(Model.initials("  "), "?")
})

test("onlineHosts only counts hosts reported true", () => {
  const cls = { computers: [{ name: "a", host: "h1" }, { name: "b", host: "h2" }] }
  assert.deepEqual(Model.onlineHosts(cls, { h1: true, h2: "true" }), ["h1"])
  assert.deepEqual(Model.onlineHosts(null, {}), [])
  assert.deepEqual(Model.allHosts(cls), ["h1", "h2"])
})

test("normalizeUrl adds https and refuses other schemes", () => {
  assert.equal(Model.normalizeUrl("code.org"), "https://code.org")
  assert.equal(Model.normalizeUrl("http://example.com/x"), "http://example.com/x")
  assert.equal(Model.normalizeUrl("javascript:alert(1)"), "")
  assert.equal(Model.normalizeUrl("file:///etc/passwd"), "")
  assert.equal(Model.normalizeUrl("two words.com"), "")
  assert.equal(Model.normalizeUrl(""), "")
})

test("message and website args are JSON objects the helper accepts", () => {
  assert.deepEqual(JSON.parse(Model.messageArgs(" Hi class ")), { title: "Message from your teacher", text: "Hi class" })
  assert.equal(Model.messageArgs("   "), "")
  assert.equal(JSON.parse(Model.messageArgs("x".repeat(900))).text.length, 500)
  assert.deepEqual(JSON.parse(Model.websiteArgs("code.org")), { websiteUrls: "https://code.org" })
  assert.equal(Model.websiteArgs("ftp://x"), "")
})

test("markup-shaped text stays inert data", () => {
  const evil = '<img src="https://example.invalid/t">'
  assert.equal(JSON.parse(Model.messageArgs(evil)).text, evil)
  assert.equal(Model.initials(evil).includes("<"), true)
})

test("parseJson and resultText", () => {
  assert.equal(Model.parseJson("not json"), null)
  assert.equal(Model.parseJson("3"), null)
  assert.deepEqual(Model.parseJson('{"ok":true}'), { ok: true })
  assert.equal(Model.resultText("Locked", 1, 0, false), "Locked 1 computer")
  assert.equal(Model.resultText("Locked", 3, 2, true), "Locked 3 computers · 2 didn't respond (sample)")
})
