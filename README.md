# DynamicObjects

## Purpose of this package

This Package's purpose is to bring Objects to Julia that can dynamically modify or add fields, as is standart in many other modern high level languages. In Julia, once a struct or NamedTuple is defined, it is impossible to add new fields to its instances. This package mainly introduces the `DynamicObject` type, for which this is possible. 


```
julia> d=DynObj( :a => 1, :b => "2"; c = BigInt(3), d = [4] )
DynamicObject with 4 entries:
  :a => 1
  :b => "2"
  :d => [4]
  :c => 3

julia> d.e = 6.0
6.0

julia> d.e + d.a - d.d[1]
3.0
```

<p>

One can add a typerestriction as the first argument to the constructor, so that all entries of this object must have the specified type:

```
julia> o = DynObj(Int; a = 1, b = 2)
DynamicObject{--,Int64} with 3 entries:
  :a => 1
  :b => 2

julia> o.c = "3"
MethodError: Cannot `convert` an object of type String to an object of type Int64
```

<p> It is also possible to add a "TypeTag" (any `Symbol`) to the `DynamicObject` type. The compiler will treat `DynamicObject`s with different Typetags as different types (because they are), allowing them to take part in the regular type and dispatch maschinery

```
julia> apply(o::DynObj{:Addcontent,T}) where T = o.a + o.b;

julia> apply(o::DynObj{:Multcontent,T}) where T = o.a * o.b;

julia> addthese = DynObj{:Addcontent}(; a = 3, b = 2);

julia> multthese = DynObj{:Multcontent}(; a = 3, b = 2);

julia> apply(addthese)
5

julia> apply(multthese)
6
```



Even though this is quite a small package, this is still work in progress, so use with caution.


