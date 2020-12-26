module soa;

import std.traits : FieldNameTuple;

/**
 * Implement Struct Of Arrays from a struct type and array size.
 *
 * Inspired by code at https://github.com/economicmodeling/soa/blob/master/soa.d
 *
 * ---
 * // Transforms a struct definition like this
 * struct Vector2 {
 *   float x = 0;
 *   float y = 0;
 * }
 * Vector2[100] arrayOfStructs;
 *
 * // To a struct definition like this
 * struct Vector2_SOA {
 *   float[100] x = 0;
 *   float[100] y = 0;
 * }
 * // alias Vector2_SOA = SOA!(Vector2, 100);
 * Vector2_SOA structOfArrays;
 * ---
 *
 * Provides a dispatching object for member access, comparison,
 * assignment and others, allowing seamless substitution of
 * Array Of Structs and Struct of Arrays types.
 *
 * FIXME: implement dispatcher ranges, opSlice
 *
 * ---
 * SOA!(Vector2, 100) vectors;
 * vectors[0].x = 10;
 * assert(vectors[0].x == 10);
 * assert(vectors[0].x == vectors.x[0]);
 * vectors[1] = Vector2(2, 2);
 * assert(vectors[1] == Vector2(2, 2));
 * ---
 */
struct SOA(T, size_t N)
if (is(T == struct))
{
    alias ElementType = T;
    alias Dispatcher = .Dispatcher!(T, N);

    // Generate one array for each field of `T` with the same name
    static foreach (i, field; FieldNameTuple!T)
    {
        mixin("typeof(T." ~ field ~ ")[" ~ N.stringof ~ "] " ~ field ~ " = T.init." ~ field ~ ";\n");
    }

    /// Returns a Dispatcher object to the pseudo-indexed `T` instance.
    auto ref opIndex(size_t i)
    {
        return Dispatcher(&this, i);
    }

    // TODO: implement Dispatcher range, opSlice
}

/**
 * Proxy object that makes it possible to use a SOA just as if it were an AOS.
 */
private struct Dispatcher(T, size_t N)
{
    SOA!(T, N)* soa;
    size_t index;

    /// Get a reference to a field by name
    private auto ref getFieldRef(string field)() inout
    {
        return __traits(getMember, soa, field)[index];
    }
    /// Returns whether two instances of dispatcher are the same.
    private bool isSame(size_t M)(auto ref Dispatcher!(T, M) other) const
    {
        static if (N == M)
        {
            return other is this;
        }
        else
        {
            return false;
        }
    }

    /// Get a reference to fields by name, dispatching to the right array at SOA instance.
    auto ref opDispatch(string op)() inout
    {
        return getFieldRef!op;
    }

    /// Assign values from a Dispatcher to another, copying each field by name to the right array.
    void opAssign(size_t M)(auto ref Dispatcher!(T, M) other)
    {
        if (!isSame(other))
        {
            static foreach (i, field; FieldNameTuple!T)
            {
                getFieldRef!field = other.getFieldRef!field;
            }
        }
    }

    /// Assign values from an instance of `T`, copying each field by name to the right array.
    void opAssign()(auto ref T value)
    {
        static foreach (i, field; FieldNameTuple!T)
        {
            getFieldRef!field = __traits(getMember, value, field);
        }
    }

    /// Compare for equality with another Dispatcher.
    bool opEquals(size_t M)(auto ref Dispatcher!(T, M) other) const
    {
        if (isSame(other))
        {
            return true;
        }
        static foreach (i, field; FieldNameTuple!T)
        {
            if (other.getFieldRef!field != getFieldRef!field)
            {
                return false;
            }
        }
        return true;
    }

    /// Compare for equality with another Dispatcher.
    bool opEquals()(auto ref const T value) const
    {
        static foreach (i, field; FieldNameTuple!T)
        {
            if (__traits(getMember, value, field) != getFieldRef!field)
            {
                return false;
            }
        }
        return true;
    }

    /// Pack `T` instance and cast to `U` if possible.
    U opCast(U)() const
    {
        T value;
        static foreach (i, field; FieldNameTuple!T)
        {
            __traits(getMember, value, field) = getFieldRef!field;
        }
        return cast(U) value;
    }
}


unittest
{
    struct Color
    {
        float r = 1;
        float g = 1;
        float b = 1;
        float a = 1;

        enum red = Color(1, 0, 0, 1);
        enum green = Color(0, 1, 0, 1);
        enum blue = Color(0, 0, 1, 1);
        enum black = Color(0, 0, 0, 1);
        enum white = Color(1, 1, 1, 1);
    }
    
    alias Color16 = SOA!(Color, 16);
    assert(is(typeof(Color16.r) == float[16]));
    assert(is(typeof(Color16.g) == float[16]));
    assert(is(typeof(Color16.b) == float[16]));
    assert(is(typeof(Color16.a) == float[16]));
    assert(Color16.init.r[0] is Color.init.r);
    assert(Color16.init.g[0] is Color.init.g);
    assert(Color16.init.b[0] is Color.init.b);
    assert(Color16.init.a[0] is Color.init.a);

    Color16 colors;
    assert(colors[0].r is Color.init.r);
    colors[0].r = 5;
    assert(colors[0].r is 5);
    assert(colors[0] == colors[0]);
    assert(colors[0] != colors[1]);
    assert(colors[1] == colors[2]);
    assert(colors[1] == Color.init);

    colors[0] = Color.white;
    assert(colors[0] == Color.white);

    colors[3] = Color.red;
    colors[2] = colors[3];
    assert(colors[2] == Color.red);
    assert(colors.r[2] == colors[2].r);
    assert(colors.g[2] == colors[2].g);
    assert(colors.b[2] == colors[2].b);
    assert(colors.a[2] == colors[2].a);

    Color c2 = cast(Color) colors[2];
    assert(c2 == Color.red);

    alias Color8 = SOA!(Color, 8);
    Color8 otherColors;
    otherColors[0] = colors[2];
    assert(otherColors[0] == Color.red);
    assert(otherColors[0] == colors[3]);
}

unittest
{
    // Transforms a struct definition like this
    struct Vector2 {
        float x = 0;
        float y = 0;
    }
    Vector2[100] arrayOfStructs;
    
    // To a struct definition like this
    struct Vector2_SOA {
        float[100] x = 0;
        float[100] y = 0;
    }
    // alias Vector2_SOA = SOA!(Vector2, 100);
    Vector2_SOA structOfArrays;

    SOA!(Vector2, 100) vectors;
    vectors[0].x = 10;
    assert(vectors[0].x == 10);
    assert(vectors[0].x == vectors.x[0]);
    vectors[1] = Vector2(2, 2);
    assert(vectors[1] == Vector2(2, 2));
}
