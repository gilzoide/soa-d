module soa;

import std.range : enumerate, isInputRange, take;
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
 * Provides a dispatching object for member access, comparison, assignment and
 * others, and also provides a Random Access Finite Range of those, allowing
 * seamless substitution of Array Of Structs and Struct Of Arrays types.
 *
 * ---
 * SOA!(Vector2, 100) vectors;
 * vectors[0].x = 10;
 * assert(vectors[0].x == 10);
 * assert(vectors[0].x == vectors.x[0]);
 * vectors[1] = Vector2(2, 2);
 * assert(vectors[1] == Vector2(2, 2));
 *
 * foreach(v; vectors[0 .. 2])
 * {
 *     import std.stdio;
 *     writeln(v.x, " ", v.y);
 * }
 * ---
 */
struct SOA(T, size_t N = 0)
if (is(T == struct))
{
    alias ElementType = T;
    alias Dispatcher = .Dispatcher!(T, N);
    alias DispatcherRange = .DispatcherRange!(T, N);

    private enum usesStaticArrays = N > 0;

    // Generate one array for each field of `T` with the same name
    static foreach (i, field; FieldNameTuple!T)
    {
        mixin("typeof(T." ~ field ~ ")[" ~ (usesStaticArrays ? N.stringof : "") ~ "] " ~ field ~ (usesStaticArrays ? " = T.init." ~ field : "") ~ ";\n");
    }

    /// Construct SOA with initial elements copied from range.
    this(R)(auto ref R range)
    if (isInputRange!R)
    {
        this[] = range;
    }

    @nogc @safe pure nothrow
    {
        /// Returns a Dispatcher object to the pseudo-indexed `T` instance.
        inout(Dispatcher) opIndex(size_t index) inout
        {
            return typeof(return)(&this, index);
        }

        /// Returns the full range of Dispatcher objects.
        inout(DispatcherRange) opIndex() inout
        {
            return typeof(return)(&this, 0, length);
        }

        /// Returns a range of Dispatcher objects.
        inout(DispatcherRange) opSlice(size_t beginIndex, size_t pastTheEndIndex) inout
        {
            return typeof(return)(&this, beginIndex, pastTheEndIndex);
        }
    }

    static if (usesStaticArrays)
    {
        /// Length of the arrays.
        enum length = N;
    }
    else
    {
        /// Length of the arrays, assumed to be the same between all of them.
        @property size_t length() const @nogc @safe pure nothrow
        {
            return __traits(getMember, this, FieldNameTuple!T[0]).length;
        }

        /// Concatenate a value.
        void opOpAssign(string op : "~")(auto ref T value)
        {
            static foreach (i, field; FieldNameTuple!T)
            {
                __traits(getMember, this, field) ~= __traits(getMember, value, field);
            }
        }

        /// Concatenate a value from Dispatcher.
        void opOpAssign(string op : "~", size_t M)(auto ref Dispatcher!(T, M) dispatcher)
        {
            static foreach (i, field; FieldNameTuple!T)
            {
                __traits(getMember, this, field) ~= __traits(getMember, dispatcher, field);
            }
        }

        /// Concatenate values from range.
        void opOpAssign(string op : "~", R)(auto ref R range)
        if (isInputRange!R)
        {
            foreach (v; range)
            {
                this ~= v;
            }
        }

        invariant
        {
            size_t firstLength = __traits(getMember, this, FieldNameTuple!T[0]).length;
            static foreach (i, field; FieldNameTuple!T[1 .. $])
            {
                assert(__traits(getMember, this, field).length == firstLength);
            }
        }
    }

    alias opDollar = length;
}

/**
 * Proxy object that makes it possible to use a SOA just as if it were an AOS.
 */
private struct Dispatcher(T, size_t N)
{
    SOA!(T, N)* soa;
    size_t index;

    invariant
    {
        assert(index < soa.length, "Dispatcher index is out of bounds");
    }

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

/**
 * Random Access Finite Range of Dispatcher objects.
 */
private struct DispatcherRange(T, size_t N)
{
    SOA!(T, N)* soa;
    size_t beginIndex;
    size_t pastTheEndIndex;

    invariant
    {
        assert(beginIndex <= pastTheEndIndex);
        assert(pastTheEndIndex <= soa.length, "DispatcherRange pastTheEndIndex is out of bounds");
    }

    @nogc @safe pure nothrow
    {
        // Input Range
        @property bool empty() const
        {
            return beginIndex >= pastTheEndIndex;
        }

        auto front() inout
        {
            return this[0];
        }

        void popFront()
        {
            beginIndex++;
        }

        // Forward Range
        inout(DispatcherRange) save() inout
        {
            return this;
        }

        // Bidirectional Range
        auto back() inout
        {
            return this[$ - 1];
        }

        void popBack()
        {
            pastTheEndIndex--;
        }

        // Random Access Finite Range
        inout(Dispatcher!(T, N)) opIndex(size_t index) inout
        {
            return typeof(return)(soa, beginIndex + index);
        }

        /// Returns a subrange.
        inout(DispatcherRange) opSlice(size_t beginIndex, size_t pastTheEndIndex) inout
        in { assert(beginIndex <= pastTheEndIndex); }
        do
        {
            return typeof(return)(soa, this.beginIndex + beginIndex, this.beginIndex + pastTheEndIndex);
        }

        /// Returns the range length.
        @property size_t length() const
        {
            return pastTheEndIndex - beginIndex;
        }

        alias opDollar = length;
    }

    // Assignments
    void opAssign()(auto ref T value)
    {
        foreach (i; 0 .. length)
        {
            this[i] = value;
        }
    }

    void opAssign(size_t M)(auto ref Dispatcher!(T, M) dispatcher)
    {
        foreach (i; 0 .. length)
        {
            this[i] = dispatcher;
        }
    }

    void opAssign(R)(auto ref R range)
    if (isInputRange!R)
    {
        size_t i = 0;
        foreach (v; range.take(length))
        {
            this[i] = v;
            i++;
        }
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
    assert(Color16.sizeof == (Color[16]).sizeof);
    assert(Color16.sizeof == 16 * Color.sizeof);
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

    // construction from range
    import std.algorithm : map;
    import std.range : enumerate, iota;
    auto alphaGradient = Color8(iota(42).map!(i => Color(1, 1, 1, i / 8f)));
    foreach (i, c; alphaGradient[].enumerate)
    {
        assert(c.a == i / 8f);
    }

    alphaGradient = Color8(iota(5).map!(i => Color(1, 1, 1, i / 8f)));
    foreach (i, c; alphaGradient[].enumerate)
    {
        if (i < 5)
        {
            assert(c.a == i / 8f);
        }
        else
        {
            assert(c == Color.init);
        }
    }

    // assignment from range
    otherColors = Color8([Color.red, Color.blue, Color.black]);
    otherColors[3 .. $] = alphaGradient[];
    assert(otherColors[0] == Color.red);
    assert(otherColors[1] == Color.blue);
    assert(otherColors[2] == Color.black);
    assert(otherColors[3] == alphaGradient[0]);
    assert(otherColors[4] == alphaGradient[1]);
    assert(otherColors[5] == alphaGradient[2]);
    assert(otherColors[6] == alphaGradient[3]);
    assert(otherColors[7] == alphaGradient[4]);

    // assignment from Color
    otherColors[$-2 .. $] = Color.green;
    assert(otherColors[$-2] == Color.green);
    assert(otherColors[$-1] == Color.green);

    // assignment from Dispatcher
    otherColors[$-2 .. $] = otherColors[0];
    assert(otherColors[$-2] == Color.red);
    assert(otherColors[$-1] == Color.red);

    // assignment from DispatcherRange
    otherColors[$-2 .. $] = otherColors[1 .. 3];
    assert(otherColors[$-2] == Color.blue);
    assert(otherColors[$-1] == Color.black);

    alias SeveralColors = SOA!(Color);
    SeveralColors several;
    several.r = new float[5];
    several.g = new float[5];
    several.b = new float[5];
    several.a = new float[5];

    several[0] = Color.red;
    assert(several[0] == Color.red);
    assert(several[1] != Color.init);  // arrays were not initialized to Color.init values

    import std.range : repeat;
    several ~= repeat(Color.red, 3);
    assert(several.length == 8);

    destroy(several.a);
    destroy(several.b);
    destroy(several.g);
    destroy(several.r);
}

unittest
{
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
}
