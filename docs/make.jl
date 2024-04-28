using MarkdownAST, AbstractTrees
using Documenter
import Markdown # necessary to reference stdlib in at-docs signatures

makedocs(
    sitename = "MarkdownAST",
    pages = [
        "Introduction" => "index.md",
        "elements.md",
        "node.md",
        "astmacro.md",
        "iteration.md",
        "Conversion to/from `Markdown`" => "stdlib.md",
    ],
    # documentation checks
    modules = [MarkdownAST],
    checkdocs = :all,
)

deploydocs(
    repo = "github.com/JuliaDocs/MarkdownAST.jl.git",
)
