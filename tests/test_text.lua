local H = require("harness")
local text = require("luadiff.text")
local test, eq = H.test, H.eq

test("split keeps track of the final newline", function()
  local l, eol = text.split("a\nb\n")
  eq(l, { "a", "b" }); eq(eol, true)
  l, eol = text.split("a\nb")
  eq(l, { "a", "b" }); eq(eol, false)
  l, eol = text.split("")
  eq(l, {}); eq(eol, true)
  l, eol = text.split("\n\n")
  eq(l, { "", "" }); eq(eol, true)
end)

test("join is the inverse of split", function()
  for _, s in ipairs({ "", "a", "a\n", "a\nb", "\n", "x\n\ny\n" }) do
    eq(text.join(text.split(s)), s)
  end
end)
