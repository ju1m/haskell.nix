# Coverage

haskell.nix can generate coverage information for your package or
project using Cabal's inbuilt hpc support.

## Prerequisites

To get a sensible coverage report, you need to enable coverage on each
of the components of your project. We recommend you use the
`overrideModules` function to do this:

```nix
let
  inherit (pkgs.haskell-nix) haskellLib;

  project = pkgs.haskell-nix.project {
    src = pkgs.haskell-nix.haskellLib.cleanGit {
      name = "haskell-nix-project";
      src = ./.;
    };
    # For `cabal.project` based projects specify the GHC version to use.
    compiler-nix-name = "ghc884"; # Not used for `stack.yaml` based projects.
  };

  projectWithCoverage = project.overrideModules(oldModules: oldModules ++ [{
    packages.$pkg.components.library.doCoverage = true;
    packages.$pkg.components.tests.a-test.doCoverage = true;
  }]);

in {
  inherit project projectWithCoverage;
}

```

## Per-package

```bash
nix-build default.nix -A "projectWithCoverage.$pkg.coverageReport'"
```

This will generate a coverage report for the package you requested. By
default, all tests that are enabled (configured with
`doCheck == true`) are included in the coverage report.

See the [developer coverage docs](../dev/coverage.md#package-reports) for more information.

## Project-wide

```bash
nix-build default.nix -A "projectWithCoverage.projectCoverageReport'"
```

This will generate a coverage report for all the local packages in
your project.

See the [developer coverage docs](../dev/coverage.md#project-wide-reports) for more information.

## Custom

By default, `projectCoverageReport'` generates a coverage report
including all the packages in your project, and `coverageReport'`
generates a report for the library and all enabled tests in the
requested package. You can modify what is included in each report by
using the `coverageReport` and `projectCoverageReport` functions.
These are found in the haskell.nix library:

```nix
let
  inherit (pkgs.haskell-nix) haskellLib;

  project = pkgs.haskell-nix.project {
    src = pkgs.haskell-nix.haskellLib.cleanGit {
      name = "haskell-nix-project";
      src = ./.;
    };
    # For `cabal.project` based projects specify the GHC version to use.
    compiler-nix-name = "ghc884"; # Not used for `stack.yaml` based projects.
  };

  projectWithCoverage = project.overrideModules(oldModules: oldModules ++ [{
    packages.$pkg.components.library.doCoverage = true;
    packages.$pkg.components.tests.a-test.doCoverage = true;
  }]);

  # Choose the library and tests you want included in the coverage
  # report for a package.
  custom$pkgCoverageReport = haskellLib.coverageReport {
    inherit (projectWithCoverage.$pkg.identifier) name version;
    inherit (projectWithCoverage.$pkg.components) library tests;
  };

  # Override the coverage report for a package, and also choose which
  # packages you want included in the coverage report.
  customProjectCoverageReport = haskellLib.projectCoverageReport {
    packages                = haskellLib.selectProjectPackages projectWithCoverage;
    coverageReportOverrides = { "${projectWithCoverage.$pkg.identifier.name}" = custom$pkgCoverageReport; };
  };
in {
  inherit project projectWithCoverage custom$pkgCoverageReport customProjectCoverageReport;
}

```
