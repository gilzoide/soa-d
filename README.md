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
Vector2_SOA structOfArrays;


alias Vector2_100 = SOA!(Vector2, 100);

Vector2_100 vectors;
vectors[0].x = 10;
assert(vectors[0].x == 10);
assert(vectors[0].x == vectors.x[0]);
vectors[1] = Vector2(2, 2);
assert(vectors[1] == Vector2(2, 2));

foreach(v; vectors[0 .. 2])
{
    import std.stdio;
    writeln(v.x, " ", v.y);
}
```
