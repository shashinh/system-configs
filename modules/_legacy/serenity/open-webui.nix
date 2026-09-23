{ config, lib, pkgs, ... }:

{
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
