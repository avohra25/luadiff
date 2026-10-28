local H = require("harness")
local unified = require("luadiff.unified")
local test, eq = H.test, H.eq

local function nums(from, to, f)
  local t = {}
  for i = from, to do t[#t + 1] = f and f(i) or ("line " .. i) end
  return table.concat(t, "\n") .. "\n"
end

test("equal inputs produce no diff", function()
  eq(unified.diff("a\nb\n", "a\nb\n"), "")
end)

test("single changed line with context", function()
  local d = unified.diff("a\nb\nc\n", "a\nB\nc\n", { from_file = "x", to_file = "y" })
  eq(d, "--- x\n+++ y\n@@ -1,3 +1,3 @@\n a\n-b\n+B\n c\n")
end)

test("distant changes split into separate hunks", function()
  local old = nums(1, 20)
  local new = nums(1, 20, function(i) return (i == 2 or i == 18) and ("LINE " .. i) or ("line " .. i) end)
  local d = unified.diff(old, new)
  local headers = {}
  for h in d:gmatch("@@ [^@]+ @@") do headers[#headers + 1] = h end
  eq(headers, { "@@ -1,5 +1,5 @@", "@@ -15,6 +15,6 @@" })
end)

test("context option controls hunk size", function()
  local d = unified.diff(nums(1, 9), nums(1, 9, function(i) return i == 5 and "five" or ("line " .. i) end), { context = 1 })
  H.truthy(d:find("@@ -4,3 +4,3 @@", 1, true), d)
end)

test("ranges of length 0 and 1 follow GNU conventions", function()
  eq(unified.diff("a\n", "a\nb\n"), "--- a\n+++ b\n@@ -1 +1,2 @@\n a\n+b\n")
  eq(unified.diff("", "x\n"), "--- a\n+++ b\n@@ -0,0 +1 @@\n+x\n")
  eq(unified.diff("x\n", ""), "--- a\n+++ b\n@@ -1 +0,0 @@\n-x\n")
end)

test("missing final newline is marked", function()
  eq(unified.diff("a\nb", "a\nb\n"),
    "--- a\n+++ b\n@@ -1,2 +1,2 @@\n a\n-b\n\\ No newline at end of file\n+b\n")
  eq(unified.diff("a\nb", "a\nc"),
    "--- a\n+++ b\n@@ -1,2 +1,2 @@\n a\n-b\n\\ No newline at end of file\n+c\n\\ No newline at end of file\n")
  eq(unified.diff("x\nb", "y\nb"),
    "--- a\n+++ b\n@@ -1,2 +1,2 @@\n-x\n+y\n b\n\\ No newline at end of file\n")
end)

test("parse round-trips the header fields and lines", function()
  local d = unified.diff("a\nb\nc\n", "a\nB\nc\nd", { from_file = "old.txt", to_file = "new.txt" })
  local files = unified.parse(d)
  eq(#files, 1)
  eq(files[1].from, "old.txt"); eq(files[1].to, "new.txt")
  local h = files[1].hunks[1]
  eq({ h.a_start, h.a_len, h.b_start, h.b_len }, { 1, 3, 1, 4 })
  eq(h.lines, { { " ", "a" }, { "-", "b" }, { "+", "B" }, { " ", "c" }, { "+", "d" } })
  eq(h.a_eol, true); eq(h.b_eol, false)
end)

test("parse handles git headers, timestamps and several files", function()
  local p = table.concat({
    "diff --git a/one b/one",
    "index 83db48f..bf269f4 100644",
    "--- a/one\t2026-10-28 09:00:00",
    "+++ b/one\t2026-10-28 09:05:00",
    "@@ -1 +1 @@ some function",
    "-x",
    "+y",
    "diff --git a/two b/two",
    "--- a/two",
    "+++ b/two",
    "@@ -0,0 +1,2 @@",
    "+p",
    "+q",
  }, "\n") .. "\n"
  local files = unified.parse(p)
  eq(#files, 2)
  eq(files[1].from, "a/one"); eq(files[1].to, "b/one")
  eq(files[2].hunks[1].lines, { { "+", "p" }, { "+", "q" } })
end)

test("parse rejects truncated or malformed hunks", function()
  H.raises(function() unified.parse("--- a\n+++ b\n@@ -1,2 +1,2 @@\n a\n") end, "ends early")
  H.raises(function() unified.parse("@@ -x +1 @@\n") end, "malformed")
  H.raises(function() unified.parse("@@ -1 +1 @@\n?what\n") end, "unexpected")
end)
