# CosmologicalEmulators

**Documentation for differentiable cosmology.** Find the common emulator
interfaces, CMB and large-scale-structure tools, and the training pipeline in one place.

Use **Julia packages** in the top navigation to switch packages. The shared
**Search everywhere** field searches the five mirrored Julia manuals and this
directory page. Python/JAX sites are linked separately, not silently mixed into
that search index.

## Where to start

- **ACE.jl** (`AbstractCosmologicalEmulators.jl`): the shared runtime layer,
  interpolation, automatic differentiation and analytic backgrounds.
- **Capse.jl**: CMB power spectrum emulation.
- **Mapse.jl**: matter power spectrum emulation and nonlinear calculations.
- **Effort.jl**: EFT-based large-scale-structure emulation.
- **EmulatorsTrainer.jl**: creating datasets, training models and validating artifacts.

## Versions and ownership

Each package maintains and tests its documentation in its own repository.
This hub mirrors published HTML and adds common navigation and search; it does
not rebuild the scientific packages or redefine their APIs.

Where available, **stable** is the default and **dev** remains accessible in the
package version selector. ACE currently has only a published **dev** manual.
Search indexes stable when present, otherwise dev, to avoid duplicate results.
Use **See All Versions** to return to the upstream package's complete version history.

The hub refreshes daily and can be rebuilt manually. Publication happens only
after the aggregate passes validation. The snapshot below records which deployed
documentation commits were used; these are not necessarily the package source heads.

To report a package documentation error, use that package's issue tracker. To fix
navigation, search, or the package list, use the
[hub repository](https://github.com/CosmologicalEmulators/CosmologicalEmulators.github.io).
