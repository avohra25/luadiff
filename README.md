# luadiff

Diff, patch and three-way merge in pure Lua 5.4, with no dependencies.

Work in progress. So far: a Myers O(ND) diff using the linear-space
"middle snake" refinement, on lines or on any array of comparable values,
with whitespace- and case-insensitive line comparison.

```sh
lua run_tests.lua
```

## License

MIT
