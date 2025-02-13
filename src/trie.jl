mutable struct Trie{T}
    value::T
    children::Dict{Char,Trie{T}}
    is_key::Bool

    function Trie{T}() where T
        self = new{T}()
        self.children = Dict{Char,Trie{T}}()
        self.is_key = false
        return self
    end

    function Trie{T}(ks, vs) where T
        t = Trie{T}()
        for (k, v) in zip(ks, vs)
            t[k] = v
        end
        return t
    end

    function Trie{T}(kv) where T
        t = Trie{T}()
        for (k,v) in kv
            t[k] = v
        end
        return t
    end
end

Trie() = Trie{Any}()
Trie(ks::AbstractVector{K}, vs::AbstractVector{V}) where {K<:AbstractString,V} = Trie{V}(ks, vs)
Trie(kv::AbstractVector{Tuple{K,V}}) where {K<:AbstractString,V} = Trie{V}(kv)
Trie(kv::AbstractDict{K,V}) where {K<:AbstractString,V} = Trie{V}(kv)
Trie(ks::AbstractVector{K}) where {K<:AbstractString} = Trie{Nothing}(ks, similar(ks, Nothing))

function Base.setindex!(t::Trie{T}, val, key::AbstractString) where T
    value = convert(T, val) # we don't want to iterate before finding out it fails
    node = t
    for char in key
        if !haskey(node.children, char)
            node.children[char] = Trie{T}()
        end
        node = node.children[char]
    end
    node.is_key = true
    node.value = value
end

function Base.getindex(t::Trie, key::AbstractString)
    node = subtrie(t, key)
    if node != nothing && node.is_key
        return node.value
    end
    throw(KeyError("key not found: $key"))
end

function subtrie(t::Trie, prefix::AbstractString)
    node = t
    for char in prefix
        if !haskey(node.children, char)
            return nothing
        else
            node = node.children[char]
        end
    end
    return node
end

function Base.haskey(t::Trie, key::AbstractString)
    node = subtrie(t, key)
    node != nothing && node.is_key
end

function Base.get(t::Trie, key::AbstractString, notfound)
    node = subtrie(t, key)
    if node != nothing && node.is_key
        return node.value
    end
    return notfound
end

function Base.keys(t::Trie, prefix::AbstractString="", found=AbstractString[])
    if t.is_key
        push!(found, prefix)
    end
    for (char,child) in t.children
        keys(child, string(prefix,char), found)
    end
    return found
end

function keys_with_prefix(t::Trie, prefix::AbstractString)
    st = subtrie(t, prefix)
    st != nothing ? keys(st,prefix) : []
end

# The state of a TrieIterator is a pair (t::Trie, i::Int),
# where t is the Trie which was the output of the previous iteration
# and i is the index of the current character of the string.
# The indexing is potentially confusing;
# see the comments and implementation below for details.
struct TrieIterator
    t::Trie
    str::AbstractString
end

# At the start, there is no previous iteration,
# so the first element of the state is undefined.
# We use a "dummy value" of it.t to keep the type of the state stable.
# The second element is 0
# since the root of the trie corresponds to a length 0 prefix of str.
function Base.iterate(it::TrieIterator, (t, i) = (it.t, 0))
    if i == 0
        return it.t, (it.t, firstindex(it.str))
    elseif i > lastindex(it.str) || !(it.str[i] in keys(t.children))
        return nothing
    else
        t = t.children[it.str[i]]
        return (t, (t, nextind(it.str, i)))
    end
end

partial_path(t::Trie, str::AbstractString) = TrieIterator(t, str)
Base.IteratorSize(::Type{TrieIterator}) = Base.SizeUnknown()

"""
    find_prefixes(t::Trie, str::AbstractString)

Find all keys from the `Trie` that are prefix of the given string

# Examples
```julia-repl
julia> t = Trie(["A", "ABC", "ABCD", "BCE"])

julia> find_prefixes(t, "ABCDE")
3-element Vector{AbstractString}:
 "A"
 "ABC"
 "ABCD"
```
"""
function find_prefixes(t::Trie, str::AbstractString)
    prefixes = AbstractString[]
    it = partial_path(t, str)
    idx = 0
    for t in it
        if t.is_key
            push!(prefixes, str[firstindex(str):idx])
        end
        idx = nextind(str, idx)
    end
    return prefixes
end