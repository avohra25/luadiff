local H = require("harness")
local merge = require("luadiff.merge")
local test, eq = H.test, H.eq

local base = "one\ntwo\nthree\nfour\nfive\nsix\nseven\n"

test("non-overlapping edits from both sides combine cleanly", function()
  local a = "ONE\ntwo\nthree\nfour\nfive\nsix\nseven\n"
  local b = "one\ntwo\nthree\nfour\nfive\nsix\nSEVEN\n"
  local out, n = merge.merge(base, a, b)
  eq(out, "ONE\ntwo\nthree\nfour\nfive\nsix\nSEVEN\n")
  eq(n, 0)
end)

test("insertions and deletions on different sides", function()
  local a = "one\ntwo\nthree\nthree and a half\nfour\nfive\nsix\nseven\n"
  local b = "one\nthree\nfour\nfive\nsix\nseven\n"
  local out, n = merge.merge(base, a, b)
  eq(out, "one\nthree\nthree and a half\nfour\nfive\nsix\nseven\n")
  eq(n, 0)
end)

test("identical changes on both sides are not a conflict", function()
  local x = "one\ntwo\nTHREE\nfour\nfive\nsix\nseven\n"
  local out, n = merge.merge(base, x, x)
  eq(out, x); eq(n, 0)
end)

test("overlapping different changes conflict", function()
  local a = "one\ntwo\nthree (ours)\nfour\nfive\nsix\nseven\n"
  local b = "one\ntwo\nthree (theirs)\nfour\nfive\nsix\nseven\n"
  local out, n = merge.merge(base, a, b, { labels = { a = "mine", b = "yours" } })
  eq(n, 1)
  eq(out, "one\ntwo\n<<<<<<< mine\nthree (ours)\n=======\nthree (theirs)\n>>>>>>> yours\nfour\nfive\nsix\nseven\n")
end)

test("diff3 style shows the base text", function()
  local a = "one\ntwo\nX\nfour\nfive\nsix\nseven\n"
  local b = "one\ntwo\nY\nfour\nfive\nsix\nseven\n"
  local out = merge.merge(base, a, b, { style = "diff3" })
  H.truthy(out:find("<<<<<<< a\nX\n||||||| base\nthree\n=======\nY\n>>>>>>> b\n", 1, true), out)
end)

test("a conflict region spans every overlapping change", function()
  -- ours edits lines 2-3, theirs edits lines 3-4: one region covering 2-4
  local a = "one\nTWO\nTHREE\nfour\nfive\nsix\nseven\n"
  local b = "one\ntwo\nthree!\nfour!\nfive\nsix\nseven\n"
  local _, n, regions = merge.merge(base, a, b)
  eq(n, 1)
  local c
  for _, r in ipairs(regions) do if r.conflict then c = r end end
  eq(c.base, { "two", "three", "four" })
  eq(c.a, { "TWO", "THREE", "four" })
  eq(c.b, { "two", "three!", "four!" })
end)

test("favor resolves conflicts to one side", function()
  local a = "one\nA\nthree\nfour\nfive\nsix\nseven\n"
  local b = "one\nB\nthree\nfour\nfive\nsix\nseven\n"
  eq((merge.merge(base, a, b, { favor = "b" })), b)
  eq((merge.merge(base, a, b, { favor = "a" })), a)
end)

test("both sides inserting at the same spot conflict", function()
  local a = "one\ntwo\nours\nthree\nfour\nfive\nsix\nseven\n"
  local b = "one\ntwo\ntheirs\nthree\nfour\nfive\nsix\nseven\n"
  local out, n = merge.merge(base, a, b)
  eq(n, 1)
  H.truthy(out:find("two\n<<<<<<< a\nours\n=======\ntheirs\n>>>>>>> b\nthree\n", 1, true), out)
end)

test("one side unchanged returns the other side", function()
  local a = "zero\none\nthree\nfive\nsix\nseven\neight\n"
  eq((merge.merge(base, a, base)), a)
  eq((merge.merge(base, base, a)), a)
end)

test("final newline change on one side is kept", function()
  eq((merge.merge("a\nb\n", "a\nb", "a\nb\n")), "a\nb")
end)
