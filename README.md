# soa
A `-betterC` compatible Struct Of Arrays template for [D](https://dlang.org).

It is available as a [DUB package](https://code.dlang.org/packages/soa)
and may be used directly as a [Meson subproject](https://mesonbuild.com/Subprojects.html)
or [wrap](https://mesonbuild.com/Wrap-dependency-system-manual.html).

SOA types provide a dispatching object for member access, comparison,
assignment and others, and also provides a Random Access Finite Range of those,
allowing seamless substitution of Array Of Structs and Struct Of Arrays types.


## Usage example
```d
import soa;

// Transforms a struct definition like this
struct Vector2
{
    float x = 0;
    float y = 0;
}
Vector2[100] arrayOfStructs;

// To a struct definition like this
struct Vector2_SOA
{
    float[100] x = 0;
    float[100] y = 0;
}
// alias Vector2_SOA = SOA!(Vector2, 100);
Vector2_SOA structOfArrays;

SOA!(Vector2, 100) vectors;
// Assignment with object type
vectors[0] = Vector2(10, 0);
// Dispatcher object handles indexing the right arrays
assert(vectors[0].x == 10);
assert(vectors[0].y == 0);
assert(vectors[0].x == vectors.x[0]);
assert(vectors[0].y == vectors.y[0]);
// Slicing works, including assignment with single value or Range
vectors[1 .. 3] = Vector2(2, 2);
assert(vectors[1] == Vector2(2, 2));
assert(vectors[2] == Vector2(2, 2));

// Also does other Range functionality
import std.stdio : writeln;
import std.range : retro;
foreach(v; vectors[0 .. 2].retro)
{
    writeln("[", v.x, ", ", v.y, "]");
}

// It is possible to also use dynamic arrays, but they must be provided or
// grown manually. All arrays must have the same length (SOA with dynamic
// arrays have an `invariant` block with this condition)
SOA!(Vector2) dynamicVectors;
dynamicVectors.x = new float[5];
dynamicVectors.y = new float[5];
scope (exit)
{
    // In this case arrays were created with `new´, so destroy them afterwards
    destroy(dynamicVectors.y);
    destroy(dynamicVectors.x);
}
assert(dynamicVectors.length == 5);

import std.algorithm : map;
import std.range : iota, enumerate;
dynamicVectors[] = iota(5).map!(x => Vector2(x, 0));
foreach (i, v; dynamicVectors[].enumerate)
{
    assert(v == Vector2(i, 0));
}

// In-place concatenate operator is available, although not available in betterC
dynamicVectors ~= Vector2(5, 0);
foreach (i, v; dynamicVectors[].enumerate)
{
    assert(v == Vector2(i, 0));
}
assert(dynamicVectors.length == 6);
```
