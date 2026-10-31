{
  flake.modules.nixos.open-webui =
    { config, lib, pkgs, ... }:

{
  # torchcodec 0.16.0 compares its mp3 encoder output against the ffmpeg CLI;
  # with ffmpeg 9.0.1 the 8 kHz mp3 cases drift past tolerance:
  #   FAILED test_encoders.py::TestEncoder::test_audio_against_cli[...-mp3-8000-...]
  #     AssertionError: Tensor-likes are not close!
  # nixpkgs already disables test_audio_against_cli on aarch64/darwin but not
  # on x86_64-linux. Without this, torchaudio -> sentence-transformers ->
  # open-webui all fail to build. (Ported from serenity's legacy config.)
  # TODO: drop once nixpkgs disables these upstream (or torchcodec retunes them).
  nixpkgs.overlays = [
    (_: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_: pyPrev: {
          torchcodec = pyPrev.torchcodec.overrideAttrs (old: {
            disabledTests = (old.disabledTests or []) ++ [ "test_audio_against_cli" ];
          });

          # posthog is marked broken since mcp went to 2.x, and chromadb is the
          # only thing that drags it into open-webui. chromadb dropped its
          # posthog usage upstream in 1.5.3, but nixpkgs still lists it.
          # TODO: drop once https://github.com/NixOS/nixpkgs/pull/580508 lands.
          chromadb = pyPrev.chromadb.overridePythonAttrs (old: {
            dependencies = builtins.filter (dep: (dep.pname or "") != "posthog") old.dependencies;
          });
        })
      ];

      # open-webui 0.12.3 pins mcp==1.27.2 and crashes at startup on the mcp 2.x
      # nixpkgs now ships (ImportError: streamablehttp_client). pythonRelaxDeps
      # hides the mismatch, so it builds fine and only fails at runtime. nixpkgs
      # reverted this same swap on policy (NixOS/nixpkgs#580672), not on merit.
      # TODO: drop once nixpkgs ships open-webui >= 0.12.5, which targets mcp 2.
      open-webui = prev.open-webui.overridePythonAttrs (old: {
        dependencies = map
          (dep: if (dep.pname or "") == "mcp" then prev.python3Packages.mcp_1 else dep)
          old.dependencies;
      });
    })
  ];

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";   # loopback only, consistent with the rest of your stack
    port = 3000;          # llama-swap already owns 8080
    openFirewall = false;

    environment = {
      # the module's own defaults — re-declare them, since setting `environment`
      # yourself replaces the defaults rather than merging with them
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";

      # point it at llama-swap's OpenAI-compatible endpoint
      OPENAI_API_BASE_URL = "http://127.0.0.1:8686/v1";
      OPENAI_API_KEY = "sk-local";  # llama-swap only validates this if you set `apiKeys` in its config — currently unset, so any non-empty string works

      # you're not running Ollama — stop it from probing for one
      ENABLE_OLLAMA_API = "False";
    };
  };
}
;
}
