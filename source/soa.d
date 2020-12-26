module soa;

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
    import std.traits : FieldNameTuple;
    static foreach (i, field; FieldNameTuple!T)
    {
        mixin("typeof(T." ~ field ~ ")[" ~ N.stringof ~ "] " ~ field ~ " = T.init." ~ field ~ ";\n");
    }

    private static struct Dispatcher
    {
        SOA* soa;
        size_t index;

        private auto ref getFieldRef(string field)() inout
        {
            return __traits(getMember, soa, field)[index];
        }

        auto ref opDispatch(string op)() inout
        {
            return getFieldRef!op;
        }

        void opAssign()(auto ref Dispatcher other)
        {
            if (other !is this)
            {
                static foreach (i, field; FieldNameTuple!T)
                {
                    getFieldRef!field = other.getFieldRef!field;
                }
            }
        }

        void opAssign()(auto ref T value)
        {
            static foreach (i, field; FieldNameTuple!T)
            {
                getFieldRef!field = __traits(getMember, value, field);
            }
        }

        bool opEquals()(auto ref Dispatcher other) const
        {
            // identity: always truthy
            if (other is this)
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

    auto ref opIndex(size_t i)
    {
        return Dispatcher(&this, i);
    }

    // TODO: implement Dispatcher range, opSlice
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
