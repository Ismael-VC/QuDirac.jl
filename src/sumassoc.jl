abstract SumAssoc{K,V} <: Associative{K,V}

Base.eltype{K,V}(::SumAssoc{K,V}) = V
labeltype{K,V}(::SumAssoc{K,V}) = K

###########
# SumTerm #
###########
immutable SumTerm{K,V} <: SumAssoc{K,V}
    key::K
    val::V
end

@compat SumTerm{K,V}(tup::Tuple{K,V}) = SumTerm{K,V}(tup[1], tup[2])

key(term::SumTerm) = term.key
val(term::SumTerm) = term.val

Base.eltype{K,V}(::Type{SumTerm{K,V}}) = V
labeltype{K,V}(::Type{SumTerm{K,V}}) = K

Base.copy(term::SumTerm) = SumTerm(key(term), val(term))

Base.promote_rule{K1,V1,K2,V2}(::Type{SumTerm{K1,V1}}, ::Type{SumTerm{K2,V2}}) = SumTerm{promote_type(K1,K2), promote_type(V1,V2)}
Base.convert{K,V}(::Type{SumTerm{K,V}}, term::SumTerm) = SumTerm(convert(K,key(term)), convert(V,val(term)))
Base.convert{K,V}(::Type{SumTerm{K,V}}, term::SumTerm{K,V}) = term

Base.keys(term::SumTerm) = tuple(key(term))
Base.values(term::SumTerm) = tuple(values(term))

Base.length(term::SumTerm) = 1

Base.getindex(term::SumTerm, x) = haskey(term, x) ? val(term) : throw(KeyError(x))

Base.start(term::SumTerm) = false
Base.next(term::SumTerm, i) = tuple(tuple(key(term), val(term)), true)
Base.done(term::SumTerm, i) = i
Base.collect(term::SumTerm) = [first(term)]

Base.haskey(term::SumTerm, k) = k == key(term)
Base.get(term::SumTerm, k, default=predict_zero(eltype(term))) = haskey(term, k) ? val(term) : default

###########
# SumTerm #
###########
type SumDict{K,V} <: SumAssoc{K,V}
    data::Dict{K,V}
    SumDict(data::Dict{K,V}) =new(data)
    SumDict(args...) = SumDict{K,V}(Dict{K,V}(args...))
end

SumDict{K,V}(data::Dict{K,V}) = SumDict{K,V}(data)
SumDict(term::SumTerm) = @compat SumDict(Dict(key(term) => val(term)))
SumDict(args...) = SumDict(Dict(args...))

Base.eltype{K,V}(::Type{SumDict{K,V}}) = V
labeltype{K,V}(::Type{SumDict{K,V}}) = K

Base.sizehint(dict::SumDict, len) = @compat (sizehint!(dict.data, len); return dict)
Base.copy(dict::SumDict) = SumDict(copy(dict.data))

Base.merge!(result::SumDict, dict::SumDict) = (merge!(result.data, dict.data); return result)

Base.hash(s::SumAssoc) = hash(filternz(s).data)
Base.hash(s::SumAssoc, h::Uint64) = hash(hash(s), h)
Base.(:(==))(a::SumAssoc, b::SumAssoc) = filternz(a).data == filternz(b).data

Base.promote_rule{K1,V1,K2,V2}(::Type{SumDict{K1,V1}}, ::Type{SumDict{K2,V2}}) = SumDict{promote_type(K1,K2), promote_type(V1,V2)}
Base.promote_rule{K1,V1,K2,V2}(::Type{SumTerm{K1,V1}}, ::Type{SumDict{K2,V2}}) = SumDict{promote_type(K1,K2), promote_type(V1,V2)}
Base.convert{K,V}(::Type{SumDict{K,V}}, term::SumTerm) = SumDict(convert(SumTerm{K,V}, term))
Base.convert{K,V}(::Type{SumDict{K,V}}, dict::SumDict) = SumDict(convert(Dict{K,V}, dict.data))
Base.convert{K,V}(::Type{SumDict{K,V}}, dict::SumDict{K,V}) = dict

Base.keys(dict::SumDict) = keys(dict.data)
Base.values(dict::SumDict) = values(dict.data)

Base.length(dict::SumDict) = length(dict.data)

Base.getindex(dict::SumDict, x) = dict.data[x]
Base.setindex!(dict::SumDict, x, y) = haskey(dict, y) ? setindex!(dict.data, x, y) : throw(KeyError(y))

Base.start(dict::SumDict) = start(dict.data)
Base.next(dict::SumDict, i) = next(dict.data, i)
Base.done(dict::SumDict, i) = done(dict.data, i)
Base.collect(dict::SumDict) = collect(dict.data)

Base.haskey(dict::SumDict, k) = haskey(dict.data, k)
Base.get(dict::SumDict, k, default=predict_zero(eltype(dict))) = get(dict.data, k, default)

#############
# Filtering #
#############
Base.filter(f::Function, term::SumTerm) = filter(f, SumDict(term))
Base.filter(f::Function, dict::SumDict) = SumDict(filter(f, dict.data))
Base.filter!(f::Function, dict::SumDict) = (filter!(f, dict.data); return dict)

nzcoeff(k,v) = v != 0

filternz(s::SumAssoc) = filter(nzcoeff, s)
filternz!(dict::SumDict) = filter!(nzcoeff, dict)

###########
# Mapping #
###########
Base.map(f::Union(Function,DataType), term::SumTerm) = SumTerm(f(key(term), val(term)))
Base.map(f::Union(Function,DataType), dict::SumDict) = SumDict(map(kv -> f(kv[1], kv[2]), collect(dict)))

function mapvals!(f, dict::SumDict)
    for (k,v) in dict
        dict.data[k] = f(v)
    end
    return dict
end

mapvals(f, term::SumTerm) = SumTerm(key(term), f(val(term)))
mapvals(f, d::SumDict) = SumDict(zip(collect(keys(d)), map(f, collect(values(d)))))
mapkeys(f, term::SumTerm) = SumTerm(f(key(term)), val(term))
mapkeys(f, d::SumDict) = SumDict(zip(map(f, collect(keys(d))), collect(values(d))))

###########
# Scaling #
###########
scale_result{K,V,T}(d::SumDict{K,V}, ::T) = SumDict{K, promote_type(T,V)}(d)

function Base.scale!(dict::SumDict, c::Number)
    for k in keys(dict)
        dict.data[k] *= c
    end
    return dict
end

Base.scale!(c::Number, dict::SumDict) = scale!(dict, c)

Base.scale(dict::SumDict, c::Number) = scale!(scale_result(dict,c), c)
Base.scale(term::SumTerm, c::Number) = SumTerm(key(term), val(term) * c)
Base.scale(c::Number, s::SumAssoc) = scale(s, c)

Base.(:*)(a::SumAssoc, b::SumAssoc) = tensor(a, b)
Base.(:*)(c::Number, s::SumAssoc) = scale(c, s)
Base.(:*)(s::SumAssoc, c::Number) = scale(s, c)
Base.(:/)(s::SumAssoc, c::Number) = scale(s, 1/c)
Base.(:-)(s::SumAssoc) = scale(s, -1)

##########
# Tensor #
##########
function tensor_merge!(result::SumDict, a::SumDict, b::SumDict)
    for (k,v) in a
        for (l,c) in b
            result.data[tensor(k,l)] = v*c
        end
    end
    return result
end

function tensor_merge!(result::SumDict, dict::SumDict, term::SumTerm)
    k0,v0 = key(term), val(term)
    for (k,v) in dict
        result.data[tensor(k,k0)] = v*v0
    end
    return result
end

function tensor_merge!(result::SumDict, term::SumTerm, dict::SumDict)
    k0,v0 = key(term), val(term)
    for (k,v) in dict
        result.data[tensor(k0,k)] = v*v0
    end
    return result
end

tensor_result{A,B,T,V}(a::SumDict{A,T}, b::SumDict{B,V}) = @compat sizehint!(SumDict{tensor_type(A,B), promote_type(T,V)}(), length(a) * length(b))
tensor_result{K,V,L,C}(d::SumDict{K,V}, ::SumTerm{L,C}) = @compat sizehint!(SumDict{tensor_type(K,L), promote_type(V,C)}(), length(d))

tensor(a::SumDict, b::SumDict) = tensor_merge!(tensor_result(a, b), a, b)
tensor(dict::SumDict, term::SumTerm) = tensor_merge!(tensor_result(dict, term), dict, term)
tensor(term::SumTerm, dict::SumDict) = tensor_merge!(tensor_result(dict, term), term, dict)
tensor(a::SumTerm, b::SumTerm) = SumTerm(tensor(key(a), key(b)), val(a) * val(b))

############
# Addition #
############
function add_to_sum!(dict::SumDict, k, v)
    if v != 0
        dict.data[k] = get(dict.data, k, 0) + v
    end
    return dict
end

function add!(result::SumDict, dict::SumDict)
    for (k,v) in dict
        add_to_sum!(result, k, v)
    end
    return result
end

add!(result::SumDict, term::SumTerm) = add_to_sum!(result, key(term), val(term))

add_result{A,B,T,V}(a::SumDict{A,T}, b::SumDict{B,V}) = SumDict{promote_type(A,B), promote_type(T,V)}()
add_result{K,V,L,C}(d::SumDict{K,V}, ::SumTerm{L,C}) = SumDict{promote_type(K,L), promote_type(V,C)}()
add_result{K,V,L,C}(::SumTerm{K,V}, ::SumTerm{L,C}) = SumDict{promote_type(K,L), promote_type(V,C)}()

Base.(:+)(a::SumDict, b::SumAssoc) = add!(merge!(add_result(a,b), a), b)
Base.(:+)(term::SumTerm, dict::SumDict) = dict + term
function Base.(:+)(a::SumTerm, b::SumTerm)
    result = add_result(a,b)
    add!(result, a)
    add!(result, b)
    return result
end

###############
# Subtraction #
###############
function sub!(result::SumDict, d::SumDict)
    for (k,v) in d
        add_to_sum!(result, k, -v)
    end
    return result
end

sub!(result::SumDict, term::SumTerm) = add_to_sum!(result, key(term), -val(term))

Base.(:-)(a::SumDict, b::SumAssoc) = sub!(merge!(add_result(a,b), a), b)

function Base.(:-)(term::SumTerm, dict::SumDict)
    result = scale!(merge!(add_result(dict,term), dict), -1)
    return add!(result, term)
end

function Base.(:-)(a::SumTerm, b::SumTerm)
    result = add_result(a,b)
    add!(result, a)
    sub!(result, b)
    return result
end
