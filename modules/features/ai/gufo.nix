# Qwen3.8 Flash-Next served by gufo (github.com/gufo-org/gufo), a Strix-Halo-only
# ROCm engine, as one more model behind llama-swap. DEPENDS on the llama-swap
# feature (it only adds to services.llama-swap.settings).
#
# Settings are the ones benchmarked in ~/Projects/serenity-localai-overhaul
# (docs/decisions.md, 2026-11-12/13): model-card sampling, MTP drafting, thinking
# effort medium (the default, xhigh, thinks ~10x longer for the same results),
# 136000-token context, one session. The model takes ~92 GB of the 108 GB GTT,
# so the matrix set below makes it run alone.
#
# The input is pinned to a release commit and does NOT follow our nixpkgs: gufo
# pins its own nixpkgs fork for ROCm 10.1, and following would force a from-source
# ROCm build. Its prebuilt closure comes from gufo.cachix.org, which is
# deliberately not a system substituter. To bump: change the rev, then build with
#   --option extra-substituters https://gufo.cachix.org
#   --option extra-trusted-public-keys gufo.cachix.org-1:rfZe3n4lHINgyoACKzs5EthIZmBNvEyCCtufUpth0PE=
{ inputs, ... }:
{
  # v0.34.0
  flake-file.inputs.gufo.url = "github:gufo-org/gufo/2845939b2a7d61243d407c8816c6d42652512e50";

  flake.modules.nixos.gufo =
    { pkgs, ... }:
    let
      gufo = inputs.gufo.packages.${pkgs.stdenv.hostPlatform.system}.release;
      modelDir = "/data/models/qwen3.8-flash-next";
      id = "qwen3.8-flash-next-Q4-gufo";
    in
    {
      services.llama-swap.settings = {
        models.${id} = {
          # gufo answers 404 for any model name it was not started with, so
          # --served-model-name must equal the llama-swap id.
          cmd = ''
            ${gufo}/bin/gufo serve llm --host 127.0.0.1 --port ''${PORT}
            --model ${modelDir}/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf
            --served-model-name ${id}
            --speculative mtp
            --mtp-model ${modelDir}/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf
            --context 136000 --sessions 1
            --temperature 1.0 --top-p 0.95 --top-k 20
            --reasoning-effort medium
          '';
          # /health only says the process is alive; /ready turns 200 once the
          # model can take requests.
          checkEndpoint = "/ready";
          ttl = 0;
        };

        matrix = {
          vars.flash = id;
          # In no other set: loading it evicts everything, and loading anything
          # else evicts it.
          sets.heavy = "flash";
        };
      };
    };
}
