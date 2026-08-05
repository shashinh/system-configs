{ config, lib, pkgs, ... }:

let
  llamaCpp = pkgs.llama-cpp.override { vulkanSupport = true; };
  llamaServer = lib.getExe' llamaCpp "llama-server";
  modelsDir = "/data/models";
in
{
  services.llama-swap = {
    enable = true;
    listenAddress = "127.0.0.1";   # loopback only — matches your local-only setup
    port = 8686;
    openFirewall = false;

    settings = {
      healthCheckTimeout = 60;
      logLevel = "info";

            # --cache-type-k q8_0 --cache-type-v q8_0
            # --cache-type-k q8_0 --cache-type-v q8_0
      models = {
        "gpt-oss-120b-f16" = {
          cmd = ''
            ${llamaServer} --port ''${PORT}
            -m ${modelsDir}/gpt-oss-120b/gpt-oss-120b-F16.gguf
            -ngl 999 -c 16384 --flash-attn on
            --no-webui
            --temp 1.0
            --min-p 0.0
            --top-p 1.0
            --top-k 0
          '';
          ttl = 0;
        };

        "qwen3-coder-next" = {
          cmd = ''
            ${llamaServer} --port ''${PORT}
            -m ${modelsDir}/qwen3/Qwen3-Coder-Next-UD-Q6_K_XL-00001-of-00003.gguf
            -ngl 999 -c 131072 --flash-attn on
            --no-webui
            --temp 1.0
            --top-p 0.95
            --min-p 0.01
            --top-k 40
          '';
          ttl = 0;
        };

        "unsloth/gemma4-26B-A4B-it" = {
          cmd = ''
            ${llamaServer} --port ''${PORT}
            -m ${modelsDir}/gemma4/gemma-4-26B-A4B-it-UD-Q6_K_XL.gguf
            --mmproj ${modelsDir}/gemma4/mmproj-BF16.gguf
            -ngl 999 -c 131072 --flash-attn on
            --no-ui
            --temp 1.0
            --top-p 0.95
            --min-p 0.01
            --top-k 64
          '';
          ttl = 0;
        };

        # "gpt-oss-120b-q4" = {
        #   cmd = ''
        #     ${llamaServer} --port ''${PORT}
        #     -m ${modelsDir}/gpt-oss-120b/gpt-oss-120b-UD-Q4_K_XL-00001-of-00002.gguf
        #     -ngl 999 -c 131072 --flash-attn on
        #     --no-webui
        #   '';
        #   ttl = 300;
        # };

        # "minimax-M2.7" = {
        #   cmd = ''
        #     ${llamaServer} --port ''${PORT}
        #     -m ${modelsDir}/minimax-IQ3_S/MiniMax-M2.7-UD-IQ3_S-00001-of-00003.gguf
        #     -ngl 999 -c 65536 --flash-attn on
        #     --no-webui
        #   '';
        #   ttl = 300;
        # };


        # "qwen3-coder-next-8" = {
        #   cmd = ''
        #     ${llamaServer} --port ''${PORT}
        #     -m ${modelsDir}/qwen3/Qwen3-Coder-Next-Q8_0-00001-of-00003.gguf
        #     -ngl 999 -c 131072 --flash-attn on
        #     --no-webui
        #     --temp 1.0
        #     --top-p 0.95
        #     --top-k 40
        #     --min-p 0.01
        #     --repeat-penalty 1.0
        #   '';
        #   ttl = 300;
        # };
 
      };



      matrix = {
        vars = {
          gpt = "gpt-oss-120b-f16";
          qwen3 = "qwen3-coder-next";
          gemma4 = "unsloth/gemma4-26B-A4B-it";
        };

        evict_costs = {
          gemma4 = 30;
          gpt = 20;
          qwen3 = 5;
        };

        sets = {
          # this combo takes up most of the 108G GTT, leaving about 16G RAM free
          daily = "gemma4 & qwen3";
        };
      };


      hooks = {
        on_startup = {
          preload = [ "unsloth/gemma4-26B-A4B-it" ];
        };
      };
    };
  };

  # DynamicUser gets no group memberships by default — needed for /dev/dri, /dev/kfd access
  systemd.services.llama-swap.serviceConfig.SupplementaryGroups = [ "render" "video" "lact-gpu-monitoring"];
}
