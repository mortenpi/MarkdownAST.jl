# Conversion methods to and from the standard library Markdown trees:
using Markdown: Markdown

"""
    convert(::Type{Node}, md::Markdown.MD) -> Node

Converts a standard library Markdown AST into MarkdownAST representation.
"""
function Base.convert(::Type{Node}, md::Markdown.MD)
    node = Node(Document())
    for md_child in md.content
        childnode = _convert_block(md_child)
        push!(node, childnode)
    end
    return node
end

function _convert(c::AbstractElement, child_convert_fn, md_children)
    node = Node(c)
    for md_child in md_children
        childnode = child_convert_fn(md_child)
        push!(node, childnode)
    end
    return node
end

_convert_block(block::Markdown.Paragraph) = _convert(Paragraph(), _convert_inline, block.content)
function _convert_block(block::Markdown.Header{N}) where N
    # Empty headings have just an empty String as text, so this requires special treatment:
    c = Heading(N)
    if block.text isa AbstractString
        # TODO: If isempty(block.text), should we omit adding any children?
        push!(Node(c), Node(Text(block.text)))
    else
        _convert(c, _convert_inline, block.text)
    end
end
_convert_block(b::Markdown.BlockQuote) = _convert(BlockQuote(), _convert_block, b.content)
_convert_block(::Markdown.HorizontalRule) = Node(ThematicBreak())
_convert_block(b::Markdown.Code) = Node(CodeBlock(b.language, b.code))
# Non-Commonmark extensions
_convert_block(b::Markdown.Admonition) = _convert(Admonition(b.category, b.title), _convert_block, b.content)
_convert_block(b::Markdown.LaTeX) = Node(DisplayMath(b.formula))
_convert_block(b::Markdown.Footnote) = _convert(FootnoteDefinition(b.id), _convert_block, b.text)

function _convert_block(b::Markdown.List)
    tight = all(isequal(1), length.(b.items))
    orderedstart = (b.ordered == -1) ? nothing : b.ordered
    list = Node(List(b.ordered == -1 ? :ordered : :bullet, tight))
    for item in b.items
        push!(list, _convert(Item(), _convert_block, item))
    end
    return list
end

function _convert_block(b::Markdown.Table)
    # TODO: I have no idea if this is even remotely correct.
    @assert length(b.rows) >= 1
    header_row, body_rows = Iterators.peel(b.rows)
    tablenode = Node(Table(Symbol[]))
    # A MD table should always contain a header
    headernode = push!(Node(TableHeader()), _convert_table_row(header_row))
    push!(tablenode, headernode)
    # If it doesn't have any more rows, then we don't append a TableBody
    if length(b.rows) >= 2
        bodynode = Node(TableBody())
        for row in body_rows
            push!(bodynode, _convert_table_row(row))
        end
        push!(tablenode, bodynode)
    end
    return tablenode
end
function _convert_table_row(row)
    rownode = Node(TableRow())
    for (i, cell) in enumerate(row)
        c = TableCell(:nothing, false, i)
        cellnode = _convert(c, _convert_inline, cell)
        push!(rownode, cellnode)
    end
    return rownode
end

# Inline nodes:
_convert_inline(s::Markdown.Bold) = _convert(Strong(), _convert_inline, s.text)
_convert_inline(s::Markdown.Italic) = _convert(Emph(), _convert_inline, s.text)
function _convert_inline(s::Markdown.Link)
    # The Base Markdown parser does not parse the title part, so we just default that to
    # an empty string.
    c = Link(s.url, "")
    if s.text isa AbstractString
        # Autolinks (the `<URL>` syntax) yield Link objects where .text is just a String
        push!(Node(c), Node(Text(s.text)))
    else
        _convert(c, _convert_inline, s.text)
    end
end
function _convert_inline(s::Markdown.Code)
    # TODO: proper error, or perhaps a warning
    @assert isempty(s.language) "Inline code span must not have language attribute"
    Node(Code(s.code))
end

# The standard library parser does not handle the title, so we just default that to an empty
# string. Also, the "alt" part inside the [] bracket is parsed as a simple string, rather
# than as proper Markdown. So we just return a corresponding Text() node.
_convert_inline(s::Markdown.Image) = @ast Image(s.url, "") do
    s.alt # TODO: if isempty(s.alt), should be just omit adding children here?
end
_convert_inline(::Markdown.LineBreak) = Node(LineBreak())
# Non-Commonmark extensions
_convert_inline(s::Markdown.LaTeX) = Node(InlineMath(s.formula))
function _convert_inline(s::Markdown.Footnote)
    @assert s.text === nothing # footnote references should not have any content, TODO: error
    Node(FootnoteLink(s.id))
end
_convert_inline(s::AbstractString) = Node(Text(s))

# TODO: Fallback methods. These should maybe use the interpolation extension?
# function _convert_inline(x)
#     @debug "Strange inline Markdown node (typeof(x) = $(typeof(x))), falling back to repr()" x
#     Text(repr(x))
# end
# function _convert_block(x)
#     @debug "Strange inline Markdown node (typeof(x) = $(typeof(x))), falling back to repr()" x
#     Paragraph([Text(repr(x))])
# end