# Handmade Hero zig

Handmade Hero personal repo written in zig (0.9.1)

# Debugging zig in vscode (cppvsdbg)
Adding breakpoints by clicking on the [editor margin](https://code.visualstudio.com/docs/editor/debugging#_breakpoints) doesn't work in my experience, for now. You can always add `@breakpoint()` but that can be a bit inconvinient.

- [Function breakpoints](https://code.visualstudio.com/docs/editor/debugging#_function-breakpoints) work but some functions can't be added by just their name. When you `@import` zig source files, they are implicitly added as structs, with a name equal to the file's basename so add the file name before function names for those to work. For instance, `handmade_sim_region.MoveEntity` should work.

- Can't add inline functions obviously as they are inlined :D.