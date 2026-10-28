# CosmologicalEmulators documentation hub

[![Documentation hub](https://github.com/CosmologicalEmulators/CosmologicalEmulators.github.io/actions/workflows/documentation.yml/badge.svg)](https://github.com/CosmologicalEmulators/CosmologicalEmulators.github.io/actions/workflows/documentation.yml)
[![docs](https://img.shields.io/badge/docs-online-blue.svg)](https://cosmologicalemulators.github.io/)

Shared navigation and search for the CosmologicalEmulators Julia documentation,
built with [MultiDocumenter.jl](https://github.com/JuliaComputing/MultiDocumenter.jl).

**[Open the documentation hub](https://cosmologicalemulators.github.io/)**

## Included sites

ACE, Capse, Mapse, Effort and EmulatorsTrainer are mirrored and searchable.
Stable and development documentation are retained where published; search uses
stable preferentially, falling back to dev. ACE currently publishes dev only.
Other releases stay available upstream through the version selector.

jaxace, jaxcapse and jaxeffort are external navigation links, not part of shared
search. jaxmapse currently has no verified working public docs URL, so the
directory links its repository instead. Other source-only projects are also
listed explicitly rather than given broken documentation links.

## Build and validate locally

Requires Julia 1.12, Git, Python 3.11+, Node.js 22 and network access for dependencies and
public documentation branches. No scientific package environments are loaded.

```bash
REPO="$PWD"
julia --startup-file=no --project="$REPO" -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project="$REPO" "$REPO/make.jl"
python3 "$REPO/test_site.py"
python3 -m http.server 8000 --directory "$REPO/build"
```

Open <http://localhost:8000/>. Use HTTP, not `file://`, for JavaScript search.
Build output, fetched sites and workstation manifests are ignored. MultiDocumenter
is pinned to 0.8.1 because version selection is required by this build.

## How updates work

`packages.toml` is the package/version/navigation inventory. The build fetches
each package's `gh-pages` branch and fails if a configured version is absent.
Only deployed HTML is copied; no upstream package source is executed. The hub
preserves each package's canonical URL. `build/upstreams.toml` and the homepage
record the exact deployed-documentation commits consumed.

MultiDocumenter adds global navigation, version links and a FlexSearch index.
The generated home page comes from `site/index.md` plus the inventory. Edit
package documentation upstream, never in the ignored cached HTML copies.

CI builds and validates pull requests without publishing. Pushes to `main`,
daily scheduled builds and manual dispatch rebuild and deploy through GitHub
Pages Actions. The deployment job has Pages/OIDC permissions; the build job has
read-only repository permissions and no deployment credential. No deploy key,
cross-repository token or `gh-pages` write access is needed in the hub.

Repository Pages settings must use **GitHub Actions**, not branch deployment.
Do not enable a custom domain here without considering existing organization
project sites. This repository does not create release tags or alter package releases.

## Add a package

1. Publish and verify the package's own Documenter site first.
2. Add its repo, unique path, name and existing versions to `packages.toml`.
3. Build locally and run the validation suite. Check navigation, version links
   and search results before merging.

Use `external` for separately hosted non-Documenter sites, and `source_only`
for projects without a verified documentation site. The shared search coverage
is explicit; adding a navigation link alone does not index that site's contents.
