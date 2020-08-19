{ lib, haskellLib, pkgs }:

{ name
, version
, library
, tests
}:

let
  buildWithCoverage = builtins.map (d: d.covered);
  runCheck = builtins.map (d: haskellLib.check d);

  testsAsList       = lib.attrValues tests;
  libraryCovered    = library.covered;
  testsWithCoverage = buildWithCoverage testsAsList;
  checks            = runCheck testsWithCoverage;

  identifier = name + "-" + version;

in pkgs.runCommand (identifier + "-coverage-report")
  { buildInputs = (with pkgs; [ ghc ]); }
  ''
    findMixDir() {
      find $1 -iwholename "*/hpc/vanilla/mix" -exec find {} -maxdepth 1 -type d -iwholename "*/mix/*" \; -quit
    }

    mkdir -p $out/share/hpc/mix/${identifier}
    mkdir -p $out/share/hpc/tix/${identifier}
    mkdir -p $out/share/hpc/html/${identifier}

    local src=${libraryCovered.src.outPath}

    hpcMarkupCmdBase=("hpc" "markup" "--srcdir=$src")
    for drv in ${lib.concatStringsSep " " ([ libraryCovered ] ++ testsWithCoverage)}; do
      # Copy over mix files
      local mixDir=$(findMixDir $drv)
      cp -R $mixDir $out/share/hpc/mix/

      hpcMarkupCmdBase+=("--hpcdir=$mixDir")
    done

    ${lib.optionalString ((builtins.length testsAsList) > 0) ''
      # Exclude test modules from tix file. The Main module is
      # hard-coded here because the Main module is not listed in
      # "$test.config.modules" (the plan.nix) but must be excluded.
      # Note that the name of the Main module file does not matter. So
      # a line in your cabal file such as:
      #   main-is: Spec.hs
      # still generates a "Main.mix" file with the contents:
      #   Mix "Spec.hs" ...
      # Hence we can hardcode the name "Main" here.
      excludedModules=('Main')
      testModules="${with lib; concatStringsSep " " (foldl' (acc: test: acc ++ test.config.modules) [] testsWithCoverage)}"
      for module in $testModules; do
        excludedModules+=("$module")
      done

      hpcSumCmdBase=("hpc" "sum" "--union" "--output=$out/share/hpc/tix/${identifier}/${identifier}.tix")
      for exclude in ''${excludedModules[@]}; do
        hpcSumCmdBase+=("--exclude=$exclude")
        hpcMarkupCmdBase+=("--exclude=$exclude")
      done

      hpcMarkupCmdAll=("''${hpcMarkupCmdBase[@]}" "--destdir=$out/share/hpc/html/${identifier}")

      hpcSumCmd=("''${hpcSumCmdBase[@]}")
      ${lib.concatStringsSep "\n" (builtins.map (check: ''
        local hpcMarkupCmdEachTest=("''${hpcMarkupCmdBase[@]}" "--destdir=$out/share/hpc/html/${check.exeName}")

        pushd ${check}/share/hpc/tix

        tixFileRel="$(find . -iwholename "*.tix" -type f -print -quit)"

        mkdir -p $out/share/hpc/tix/$(dirname $tixFileRel)
        cp $tixFileRel $out/share/hpc/tix/$tixFileRel

        # Output tix file with test modules excluded
        hpcSumCmd+=("$out/share/hpc/tix/$tixFileRel")

        hpcMarkupCmdEachTest+=("$out/share/hpc/tix/$tixFileRel")

        echo "''${hpcMarkupCmdEachTest[@]}"
        eval "''${hpcMarkupCmdEachTest[@]}"

        popd
      '') checks)
      }

      hpcMarkupCmdAll+=("$out/share/hpc/tix/${identifier}/${identifier}.tix")

      echo "''${hpcSumCmd[@]}"
      eval "''${hpcSumCmd[@]}"

      echo "''${hpcMarkupCmdAll[@]}"
      eval "''${hpcMarkupCmdAll[@]}"
    ''}
  ''
