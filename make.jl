using Documenter, MultiDocumenter, TOML

const ROOT = @__DIR__
const CACHE = joinpath(ROOT, ".cache")
const CONFIG = TOML.parsefile(joinpath(ROOT, "packages.toml"))
const PACKAGES = CONFIG["packages"]
const DOMAIN = "https://cosmologicalemulators.github.io"

mkpath(CACHE)
length(unique(p["path"] for p in PACKAGES)) == length(PACKAGES) ||
    error("Package paths must be unique")

# Fetch deployed HTML, never execute upstream package source. Fail rather than
# publish stale cached content if a fetch fails.
provenance = Dict{String,Any}()
for p in PACKAGES
    checkout = joinpath(CACHE, "upstream", p["repo"])
    url = "https://github.com/CosmologicalEmulators/$(p["repo"]).git"
    if !isdir(checkout)
        mkpath(dirname(checkout))
        run(`git clone --depth 1 --single-branch --branch gh-pages $url $checkout`)
    else
        run(`git -C $checkout fetch --depth 1 origin gh-pages`)
        run(`git -C $checkout checkout --detach FETCH_HEAD`)
    end
    for version in p["versions"]
        isfile(joinpath(checkout, version, "index.html")) ||
            error("Missing published $(p["repo"])/$version/index.html")
    end
    provenance[p["repo"]] = Dict(
        "commit" => strip(read(`git -C $checkout rev-parse HEAD`, String)),
        "versions" => p["versions"],
        "url" => url,
    )
end

# Generate only the hub's directory page. Package docs remain owned upstream.
source = joinpath(CACHE, "home-source")
landing = joinpath(CACHE, "home")
mkpath(source)
intro = read(joinpath(ROOT, "site", "index.md"), String)
open(joinpath(source, "index.md"), "w") do io
    write(io, intro)
    println(io, "\n## Julia documentation\n")
    println(io, "| Package | Scope | Included versions |\n|:--|:--|:--|")
    for p in PACKAGES
        println(io, "| [$(p["name"])]($(DOMAIN)/$(p["path"])/) | $(p["description"]) | $(join(p["versions"], ", ")) |")
    end
    println(io, "\n## Python / JAX documentation\n")
    println(io, "These independently hosted sites open outside the hub and are **not** included in its shared search.\n")
    for p in CONFIG["external"]
        println(io, "- [$(p["name"])]($(p["url"]))")
    end
    println(io, "\n## More ecosystem projects\n")
    println(io, "Source repositories, not mirrored documentation sites:\n")
    for p in CONFIG["source_only"]
        println(io, "- [$(p["name"])](https://github.com/CosmologicalEmulators/$(p["repo"]))")
    end
    println(io, "\n## Snapshot provenance\n")
    println(io, "The hub copies deployed documentation, not the current package source. Exact upstream documentation commits used in this build:\n")
    for p in PACKAGES
        sha = provenance[p["repo"]]["commit"]
        println(io, "- $(p["name"]): [`$(sha[1:12])`](https://github.com/CosmologicalEmulators/$(p["repo"])/commit/$sha)")
    end
end

makedocs(
    root=ROOT,
    source=source,
    build=joinpath(landing, "dev"),
    sitename="CosmologicalEmulators",
    authors="CosmologicalEmulators contributors",
    pages=["Documentation hub" => "index.md"],
    remotes=nothing,
    warnonly=false,
    format=Documenter.HTML(
        prettyurls=true,
        edit_link=nothing,
        repolink="https://github.com/CosmologicalEmulators/CosmologicalEmulators.github.io",
        canonical="$DOMAIN/home/dev/",
        inventory_version="dev",
    ),
)
# This local directory page is not deployed by Documenter, so supply the two
# version-selector files that deploydocs normally writes.
write(joinpath(landing, "versions.js"), "var DOC_VERSIONS = [\"dev\"];\nvar DOCUMENTER_NEWEST = \"dev\";\n")
write(joinpath(landing, "dev", "siteinfo.js"), "var DOCUMENTER_CURRENT_VERSION = \"dev\";\nvar DOCUMENTER_STABLE = \"dev\";\n")

refs = [MultiDocumenter.MultiDocRef(
    upstream=landing, path="home", name="Home",
    versions=MultiDocumenter.VersionSelection(["dev"]),
)]
for p in PACKAGES
    push!(refs, MultiDocumenter.MultiDocRef(
        upstream=joinpath(CACHE, "upstream", p["repo"]),
        path=p["path"], name=p["name"],
        versions=MultiDocumenter.VersionSelection(p["versions"];
            all_versions_url="$DOMAIN/$(p["repo"])/"),
        # Retain each package site's own canonical URLs: this is a mirror.
        fix_canonical_url=false,
    ))
end

navigation = [
    first(refs),
    MultiDocumenter.DropdownNav("Julia packages", refs[2:end]),
    MultiDocumenter.DropdownNav("Python / JAX", [
        MultiDocumenter.Link(p["name"], p["url"]) for p in CONFIG["external"]
    ]),
    MultiDocumenter.Link("GitHub", "https://github.com/CosmologicalEmulators"),
]

MultiDocumenter.make(joinpath(ROOT, "build"), navigation;
    rootpath="/",
    canonical_domain=DOMAIN,
    # FlexSearch indexes the first available version only: stable, else dev.
    search_engine=MultiDocumenter.SearchConfig(
        index_versions=["stable", "dev"], engine=MultiDocumenter.FlexSearch),
)
for p in PACKAGES
    checkout = joinpath(CACHE, "upstream", p["repo"])
    actual = strip(read(`git -C $checkout rev-parse HEAD`, String))
    actual == provenance[p["repo"]]["commit"] ||
        error("$(p["repo"]) changed during aggregation; rebuild for consistent provenance")
end
open(joinpath(ROOT, "build", "upstreams.toml"), "w") do io
    TOML.print(io, provenance; sorted=true)
end
touch(joinpath(ROOT, "build", ".nojekyll"))
