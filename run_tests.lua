-- Run every test file: lua run_tests.lua
local dir = arg[0]:match("^(.*)/[^/]*$") or "."
package.path = dir .. "/src/?.lua;" .. dir .. "/src/?/init.lua;" .. dir .. "/tests/?.lua;" .. package.path

local H = require("harness")
local files = { "test_myers", "test_text", "test_unified", "test_patch", "test_merge" }
for _, f in ipairs(files) do
  local before = H.passed + H.failed
  require(f)
  io.write(string.format("%-16s %d tests\n", f, H.passed + H.failed - before))
end
for _, msg in ipairs(H.failures) do io.write("FAIL ", msg, "\n\n") end
io.write(string.format("%d passed, %d failed\n", H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
