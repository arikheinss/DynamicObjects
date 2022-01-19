module DynamicObjects


import Base:getproperty,setproperty!, haskey, get, get!,propertynames ,
    getindex, setindex!, iterate, length
export DynamicObject, dtype, typetag, DynObj


const defaultTag = gensym("default")

docstr="""
```
DynamicObject{TypeTag,T}  <: AbstractDict{Symbol,T}
```

<p>
Constructors:

```
DynamicObject([type,] pairs::Pair{Symbol, <: T}...; kwargs...)
DynamicObject{TypeTag}([type,] pairs::Pair{Symbol, <: T}...; kwargs...)
```
<p>

Alias: `DynObj`

Create an Object whose fields can be dynamically added and modified. Constructor 
takes both positional `Symbol=>Value`-pairs, as well as arbitrary keywords.

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

One can add a typerestriction as the first argument to the constructor, so that all entries of this object must have
the specified type:

```
julia> o = DynObj(Int; a = 1, b = 2)
DynamicObject{--,Int64} with 3 entries:
  :a => 1
  :b => 2

julia> o.c = "3"
MethodError: Cannot `convert` an object of type String to an object of type Int64
```
<p>
It is also possible to add a "TypeTag" (any `Symbol`) to the `DynamicObject` type. The compiler will
treat `DynamicObject`s with different Typetags as different types (because they are), allowing
them to take part in the regular type and dispatch maschinery

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
"""

struct DynamicObject{TypeTag,T} <: AbstractDict{Symbol,T}
    d::Dict{Symbol,T}
    DynamicObject{TT,T}(p::Pair{Symbol,<:T}...;kwargs...) where {TT,T} = new{TT,T}(Dict{Symbol,T}(p...,kwargs...)) 
    
end
const DynObj = DynamicObject
@doc docstr DynamicObject
@doc docstr DynObj


DynamicObject(args...;kwargs...)=DynamicObject{defaultTag}(args...;kwargs...)
DynamicObject{T}(::Type{S},args...;kwargs...) where{T,S}=DynamicObject{T,S}(args...;kwargs...)
DynamicObject{T}(args...;kwargs...) where {T}=DynamicObject{T,Any}(args...;kwargs...)


_getdict(o::DynamicObject) = getfield(o,:d)

"""
```
typetag(::DynamicObject{TT,T}) where {TT,T} 
```
Returns the applied `TypeTag` of the Object.
"""
typetag(::DynamicObject{TT,T}) where {TT,T} = TT

"""
```
dtype(::DynamicObject{TT,T}) where {TT,T} 
```
Returns the value type of the object
"""
dtype(::DynamicObject{TT,T}) where {TT,T} = T


getproperty(o::DynamicObject,s::Symbol) = _getdict(o)[s]
setproperty!(o::DynamicObject,s::Symbol,x) = (_getdict(o)[s]=x)
propertynames(o::DynamicObject) = Tuple(keys(_getdict(o)))

    # these functions are to be inherited from Dict
    let mapfunctions=( :( haskey(o::DynamicObject,k) ), 
        :(get(this::DynamicObject,key,def)), :(get!(this::DynamicObject, key,def)), 
        :(iterate(o::DynamicObject)) ,       :(iterate(o::DynamicObject,i)), 
            :(getindex(o::DynamicObject,i)), :(setindex!(o::DynamicObject,i,val)),
        :(length(o::DynamicObject)),
                

    )
    for expr in mapfunctions
        @assert expr.head==:call
        func,args... = expr.args
        # construct the arguments for nessecary function calls
        newargs = [  
            if (e isa Expr) && (e.head==Symbol("::"))
                if e.args[2] == :DynamicObject
                    :( getfield($(e.args[1]), :d))
                else
                    e.args[1]
                end
            else
                e
            end        

                    for e in args
        ]
        @eval $func($(args...)) = $func($(newargs...)) 
    end
        end

function Base.showarg(io::IO,::DynamicObject{TT,T},toplvl) where {TT,T}
    toplvl || print(io,"::")
    tt = TT == defaultTag ? "--" : repr(TT)
    if T == Any && TT == defaultTag
        print(io,"DynamicObject")
    else    
        print(io,"DynamicObject{",tt,",", T ,"}")
    end
end

      
end # module
