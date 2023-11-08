{pkgs, rutter-openapi-spec}:
let 
  config = pkgs.writeText "config.yaml"
    ''
      allowNonUniqueOperationIds: true
      strictFields: false
      cabalPackage: rutter-hs
      baseModule: Rutter
      requestType: RutterRequest 
      configType: RutterConfig
      typeMappings:
        AnyType: A.Value
    '';
in pkgs.writeShellScriptBin "generate"
''
  set -eux

  TAG="$1"
  OUT="generated-client"

  if [ "$TAG" = "" ]; then
      echo "Tag name is missing"
      exit 1
  fi

  SPECFILE=$(mktemp)
  
  cat ${rutter-openapi-spec} > $SPECFILE

  echo "Modifying openapi spec version from 3.1.0 to 3.0.3"
  ${pkgs.yq}/bin/yq -y -i '.openapi = "3.0.3"' $SPECFILE

  echo "Generating CLI"
  ${
    builtins.concatStringsSep " "
    [ 
      "${pkgs.openapi-generator-cli}/bin/openapi-generator-cli generate "
      "--skip-validate-spec"
      "-i $SPECFILE"
      "-g haskell-http-client"
      "-o $OUT"
      "-c ${config}"
    ]
  } &> /dev/null
  
  echo "Copying LICENSE"
  cp LICENSE $OUT/

  echo "Updating cabal file"
  sed -i 's/UnspecifiedLicense/MIT/g' $OUT/rutter-hs.cabal


''
