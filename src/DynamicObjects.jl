module DynamicObjects


import Base:getproperty,setproperty!, haskey, get, get!,propertynames ,
    getindex, setindex!, iterate, length
export DynamicObject, dtype, typetag, DynObj, @Dynamic


const defaultTag = gensym("default")

#=docstr="""
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
=#

struct DynamicObject{TypeTag, T} <: AbstractDict{Symbol,Any}
    fields::T
    d::Dict{Symbol,Any}
    
    DynamicObject{TT,Nothing}(p::Pair{Symbol,_T}...;kwargs...) where {TT,_T} = new{TT,Nothing}(Dict{Symbol,Any}(p...,kwargs...))
    DynamicObject{TT,_T}(args...;kwargs...) where {TT,_T} =begin
        nfields=fieldcount(_T)
        _fields=_T(args[1:nfields])
        _d=Dict(args[nfields+1:end]...,kwargs...)
        return new(_fields,_d)
    end

    
end

const DynObj = DynamicObject
const _UnspecificObject = DynamicObject{T,Nothing} where T
#@doc docstr DynamicObject
#@doc docstr DynObj


DynamicObject(args...;kwargs...)=DynamicObject{defaultTag,Nothing}(args...;kwargs...)
#DynamicObject{T}(::Type{S},args...;kwargs...) where{T,S}=DynamicObject{T,S}(args...;kwargs...)
DynamicObject{T}(args...;kwargs...) where {T}=DynamicObject{T,Nothing}(args...;kwargs...)
#DynamicObject{TT,T}(args...,kwargs...)


_getdict(o::DynamicObject) = getfield(o,:d)
_getfields(o::DynamicObject) = getfield(o,:fields)

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
typespec(::DynamicObject{TT,T}) where {TT,T} = T


getproperty(o::_UnspecificObject,s::Symbol) = _getdict(o)[s]
getproperty(o::DynamicObject{TT,T}, s::Symbol) where {TT,T} = s in fieldnames(T) ? getfield(_getfields(o),s) : _getdict(o)[s]

setproperty!(o::_UnspecificObject,s::Symbol,x) = (_getdict(o)[s]=x)
setproperty!(o::DynamicObject{TT,T}, s::Symbol, x) where {TT,T} = s in fieldnames(T) ? setproperty!(_getfields(o),s,x) : (_getdict(o)[s] = x)

propertynames(o::_UnspecificObject) = Tuple(keys(_getdict(o)))
propertynames(o::DynamicObject{TT,T}) where {TT,T} = keys(_getdict(o)) ∪ fieldnames(T)

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


macro Dynamic(expr::Expr)
    expr.head==:struct || throw("Dynamic handles structdefs only")
    expr.args[2] isa Expr && expr.args[2].head == :curly && throw("Parametric structdefs not supported")
    @assert expr.args[1] isa Bool && expr.args[2] isa Symbol && expr.args[3] isa Expr && expr.args[3].head == :block  "Format of the struct definition not understood."
    
    typename = expr.args[2]
    fieldlist = expr.args[3].args
    
    fieldnames=[]
    fieldtypes=[]
    
    #print(fieldlist)
    for e in fieldlist
        if e isa LineNumberNode
            continue
        elseif e isa Symbol
            push!(fieldnames,e)
            push!(fieldtypes,Any)
        elseif e isa Expr && e.head == Symbol("::")
            push!(fieldnames,e.args[1])
            push!(fieldtypes, eval(e.args[2]))
        else
            throw("Format of fields not understood")
        end
    end
    
    #println(fieldnames)
    #println(fieldtypes)
    typeparam=length(fieldlist)==0 ? Nothing : NamedTuple{Tuple(fieldnames), Tuple{fieldtypes...}}
    retEx=quote
        const $(esc(typename)) = DynamicObject{$(QuoteNode(typename)), $typeparam}
    end
    return retEx
end
        
    
    
      
end # module
