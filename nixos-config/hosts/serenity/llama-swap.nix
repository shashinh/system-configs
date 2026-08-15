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
      healthCheckTimeout = 240;
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

        "qwen3.6-35B-MTP-F16-coding" = {
          cmd = ''
            ${llamaServer} --port ''${PORT}
            -m ${modelsDir}/qwen3.6/MTP/BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf
            --mmproj ${modelsDir}/qwen3.6/MTP/mmproj-F16.gguf
            -ngl 999 -c 131072 --flash-attn on
            --no-webui
            --temp 0.6
            --top-p 0.95
            --min-p 0.00
            --top-k 20
            --spec-type draft-mtp --spec-draft-n-max 2            
          '';
          ttl = 0;
        };

        "qwen3.6-35B-MTP-F16-general" = {
          cmd = ''
            ${llamaServer} --port ''${PORT}
            -m ${modelsDir}/qwen3.6/MTP/BF16/Qwen3.6-35B-A3B-BF16-00001-of-00002.gguf
            --mmproj ${modelsDir}/qwen3.6/MTP/mmproj-F16.gguf
            -ngl 999 -c 131072 --flash-attn on
            --no-webui
            --temp 1.0
            --top-p 0.95
            --top-k 20
            --min-p 0.00
          '';
          ttl = 0;
        };

        "qwen3.6-35B-MTP-Q8-coding" = {
          cmd = ''
            ${llamaServer} --port ''${PORT}
            -m ${modelsDir}/qwen3.6/MTP/q8/Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf
            --mmproj ${modelsDir}/qwen3.6/MTP/q8/mmproj-F16.gguf
            -ngl 999 -c 262144 --flash-attn on
            --no-webui
            --temp 0.6
            --top-p 0.95
            --min-p 0.00
            --top-k 20
            --spec-type draft-mtp --spec-draft-n-max 2            
          '';
          ttl = 0;
        };

        "qwen3.6-35B-MTP-Q8-general" = {
          cmd = ''
            ${llamaServer} --port ''${PORT}
            -m ${modelsDir}/qwen3.6/MTP/q8/Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf
            --mmproj ${modelsDir}/qwen3.6/MTP/q8/mmproj-F16.gguf
            -ngl 999 -c 262144 --flash-attn on
            --no-webui
            --temp 1.0
            --top-p 0.95
            --top-k 20
            --min-p 0.00
          '';
          ttl = 0;
        };

        "qwen3.6-27B-MTP-Q4-coding" = {
          cmd = ''
            ${llamaServer} --port ''${PORT}
            -m ${modelsDir}/qwen3.6-27B/Qwen3.6-27B-UD-Q4_K_XL.gguf
            --mmproj ${modelsDir}/qwen3.6-27B/mmproj-F16.gguf
            -ngl 999 -c 262144 --flash-attn on
            --no-webui
            --temp 0.6
            --top-p 0.95
            --min-p 0.00
            --top-k 20
            --spec-type draft-mtp --spec-draft-n-max 3            
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
 
      };



      matrix = {
        vars = {
          gpt = "gpt-oss-120b-f16";
          q3 = "qwen3-coder-next";
          gemma4 = "unsloth/gemma4-26B-A4B-it";
          q36mtp = "qwen3.6-35B-MTP-Q8-coding";
        };

        evict_costs = {
          gemma4 = 30;
          gpt = 20;
          q3 = 5;
          #qwen36mtp=10;
        };

        sets = {
          # this combo takes up most of the 108G GTT, leaving about 16G RAM free
          daily = "gemma4 & q3";
          coding = "gemma4 & q36mtp";
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
