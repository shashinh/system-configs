# Declarative Firefox config via home-manager's `programs.firefox` module.
#
# NOT imported into home.nix yet. Right now Firefox is provided by the NixOS
# system module instead (see hosts/pc-common.nix's `programs.firefox`), which
# only covers package/policies/native-messaging-hosts. This file exists as a
# reference for a future switch to home-manager, once ready to hand profile
# management over to Nix.
#
# The values below were reverse-engineered from the real profile on this
# machine (~/.config/mozilla/firefox/<hash>.default) on 2026-08-16: prefs.js,
# search.json.mozlz4, handlers.json, containers.json and the installed
# extensions. They mirror what's actually configured today, not a fresh
# default. See the extensions.packages comment near the bottom for a caveat
# on migrating.
#
# Every option below is documented inline; anything the current profile
# doesn't use is included commented-out (or noted) so the full tunable
# surface is visible in one place.

{ pkgs, inputs, ... }:

{
  programs.firefox = {
    enable = true;

    # The Firefox package to install. Defaults to pkgs.firefox (wrapped).
    # Override here (e.g. pkgs.firefox-esr, or pkgs.firefox.override { ... })
    # if you ever need a different channel/build. Left at default.
    # package = pkgs.firefox;

    # Extra native messaging host packages, made available to extensions
    # that talk to a local helper binary (e.g. a password manager's native
    # app, or KDE's browser integration). The NixOS system module currently
    # supplies kdePackages.plasma-browser-integration via
    # hosts/pc-common.nix's `programs.firefox.nativeMessagingHosts.packages`.
    # If this module ever replaces the system one, that package would need
    # to move here:
    # nativeMessagingHosts = [ pkgs.kdePackages.plasma-browser-integration ];

    # Firefox language packs to install (locale UI translations). This
    # profile is en-US only, so nothing is needed.
    # languagePacks = [ "de" "en-GB" ];

    # Enterprise policies (policies.json), applied via the wrapped package.
    # Same schema as the NixOS module's `programs.firefox.policies` (see
    # https://mozilla.github.io/policy-templates/), but scoped to this user
    # instead of system-wide. Useful for things like locking preferences,
    # disabling about:config, or setting a default download directory.
    # Not currently used — the profile-level `settings` below covers the
    # equivalent about:config prefs without needing policies.
    # policies = {
    #   DisableAppUpdate = true;
    #   DefaultDownloadDirectory = "${config.home.homeDirectory}/Downloads";
    # };

    # Force-install an extension across every profile via the policy
    # engine (rather than per-profile via profiles.<name>.extensions).
    # Not used here since all extensions below are scoped to one profile.
    # globalExtensions = [ ];

    # Additional PKCS #11 (smartcard/security token) modules to load.
    # Not used on this machine.
    # pkcs11Modules = [ ];

    profiles.default = {
      # Matches the existing profile's Name=default in profiles.ini.
      id = 0;
      isDefault = true; # true is already implied by id == 0, set explicitly for clarity.

      # The on-disk directory name under the profile, relative to
      # configPath. Home-manager defaults this to the attribute name
      # ("default"), but the real profile on this machine currently lives
      # under a random-prefixed directory (s3hicg4a.default, assigned by
      # Firefox itself at profile creation). When this module is actually
      # enabled, decide whether to let home-manager create a fresh profile
      # at "default" (losing history/logins/sessions unless migrated) or
      # set `path = "s3hicg4a.default";` to adopt the existing one in place.
      # path = "default";

      # Arbitrary about:config preferences, written to user.js. Firefox
      # only supports bool/int/string prefs internally; home-manager
      # auto-serializes anything else (lists/attrs) to a JSON string, which
      # is how Firefox itself stores structured prefs like pinned tiles.
      settings = {
        # Startup behavior: 0 = blank page, 1 = home page, 2 = last visited
        # page, 3 = restore windows/tabs from the previous session.
        "browser.startup.page" = 3;
        "browser.startup.homepage" = "nytimes.com";

        # Firefox's built-in "New Tab" page (top sites/sponsored tiles) is
        # turned off, with a single pinned tile kept for Google.
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.pinned" = [
          {
            url = "https://google.com";
            label = "@google";
            searchTopSite = true;
            baseDomain = "google.com";
          }
        ];

        # Don't remember values typed into web forms.
        "browser.formfill.enable" = false;

        # Always ask where to save a file instead of using a fixed
        # downloads directory.
        "browser.download.useDownloadDir" = false;

        # Ctrl+Tab cycles tabs in most-recently-used order rather than
        # left-to-right tab order.
        "browser.ctrlTab.sortByRecentlyUsed" = true;

        # Don't show search-engine suggestions above browsing/bookmark
        # history in the address bar dropdown.
        "browser.urlbar.showSearchSuggestionsFirst" = false;

        # Show the bookmarks toolbar's mobile-bookmarks folder.
        "browser.bookmarks.showMobileBookmarks" = true;

        # Never offer to save logins/passwords in Firefox's built-in
        # manager — this machine uses Bitwarden instead (see
        # extensions.packages below).
        "signon.rememberSignons" = false;

        # Send the Global Privacy Control signal (a stronger, legally
        # backed successor to Do Not Track) with every request.
        "privacy.globalprivacycontrol.enabled" = true;

        # Clear form data automatically on shutdown.
        "privacy.clearOnShutdown_v2.formdata" = true;

        # Privacy/perf hardening around network prefetching: don't
        # pre-resolve DNS for links, don't prefetch linked pages, and
        # don't open speculative parallel connections ahead of navigation.
        "network.dns.disablePrefetch" = true;
        "network.prefetch-next" = false;
        "network.http.speculative-parallel-limit" = 0;

        # Keep the new vertical tabs sidebar hidden.
        "sidebar.visibility" = "hide-sidebar";
      };

      # Extra raw lines appended to user.js after `settings`, for anything
      # not worth modeling as a single key/value pref. Not needed here.
      # extraConfig = '''';

      # Like extraConfig, but written *before* `settings` — use this only
      # if you need `settings` to be able to override it.
      # preConfig = '''';

      # Custom chrome/content CSS (chrome://browser UI tweaks and
      # page-content tweaks, respectively). This profile has no
      # chrome/userChrome.css or userContent.css on disk, so both are
      # unused.
      # userChrome = "";
      # userContent = "";

      # Declarative default search engine + ordering. `force` is required
      # (and recommended by upstream) because Firefox replaces
      # search.json.mozlz4's symlink on every launch, so without it any
      # manual in-browser reordering would just get discarded silently.
      search = {
        force = true;
        default = "google";
        # privateDefault = null; # No separate private-browsing engine set.
        order = [
          "google"
          "amazondotcom-us" # Amazon.com
          "bing"
          "ddg" # DuckDuckGo
          "perplexity"
          "wikipedia" # Wikipedia (en)
          "ebay"
        ];
        # Fully custom (non-built-in) search engines would go here, e.g.:
        # engines."nix-packages" = {
        #   name = "Nix Packages";
        #   urls = [{ template = "https://search.nixos.org/packages?query={searchTerms}"; }];
        #   definedAliases = [ "@np" ];
        # };
      };

      # Declarative default-app handlers for MIME types / URL schemes
      # (handlers.json). `action`: 0 = save file, 1 = always ask, 2 = use
      # helper app, 3 = open in Firefox, 4 = use system default.
      handlers = {
        mimeTypes = {
          "application/pdf" = {
            action = 3; # open in Firefox's built-in PDF viewer
            extensions = [ "pdf" ];
          };
          "image/webp" = {
            action = 3;
            extensions = [ "webp" ];
          };
          "image/avif" = {
            action = 3;
            extensions = [ "avif" ];
          };
        };
        schemes.mailto = {
          # `handlers` is an ordered list, first entry is the default.
          # An empty object means "no default, ask every time" — matches
          # this profile's current behavior of not auto-picking Gmail.
          handlers = [
            { }
            {
              name = "Gmail";
              uriTemplate = "https://mail.google.com/mail/?extsrc=mailto&url=%s";
            }
          ];
        };
        # Note: this profile also has handlers for the `ext+treestyletab`
        # and `zoomus` schemes, but those are auto-registered at runtime by
        # the Tree Style Tab extension and the Zoom desktop app
        # respectively — not worth hardcoding here.
      };

      # Multi-Account Containers (id/color/icon). Firefox creates the four
      # built-in containers (Personal/Work/Banking/Shopping, ids 1-4)
      # automatically on every fresh profile, so they don't need to be
      # declared. This profile also has a 5th container ("Facebook", id 6),
      # but that one is auto-created and managed by the Facebook Container
      # extension itself (see extensions.packages below) — declaring it
      # here would fight with the extension rather than help, so it's
      # intentionally left out. Example shape, if you ever add a container
      # by hand instead of via an extension:
      # containers.shopping = {
      #   id = 5;
      #   color = "pink";
      #   icon = "cart";
      # };

      # Declarative bookmarks (toolbar/menu folders, keywords, tags),
      # force-overwriting whatever's in the profile. This machine's
      # bookmarks are real, UI-managed data in places.sqlite — leaving
      # this unset avoids clobbering them. Only turn this on with a
      # deliberate, complete bookmark tree.
      # bookmarks = { force = true; settings = [ ... ]; };

      # Extensions installed for this profile. Sourced from NUR's
      # community-maintained firefox-addons repo (nur.repos.rycee), which
      # packages each extension's .xpi with its addonId exposed so
      # home-manager can install and force-enable it.
      #
      # NUR is NOT currently a flake input in this repo (see flake.nix) —
      # add `nur.url = "github:nix-community/NUR";` there first, or this
      # section won't evaluate. `inputs.nur.legacyPackages.${pkgs.system}`
      # is used directly below rather than an overlay, so no other changes
      # are required beyond adding the input.
      #
      # Every addonId below was checked against this machine's real
      # extensions.json and matches exactly.
      extensions.packages =
        with inputs.nur.legacyPackages.${pkgs.system}.repos.rycee.firefox-addons;
        [
          ublock-origin # uBlock Origin
          bitwarden # Bitwarden Password Manager
          tridactyl # Tridactyl (vim-style keyboard nav)
          tree-style-tab # Tree Style Tab
          facebook-container # Facebook Container
          grammarly # Grammarly: AI Writing and Grammar Checker
          instapaper-official # Instapaper
          joplin-web-clipper # Joplin Web Clipper
          downthemall # DownThemAll!
          tranquility-1 # Tranquility Reader
          plasma-integration # Plasma Browser Integration
          # Two currently-installed extensions have NO match in NUR's
          # firefox-addons repo (checked by addonId, not just by name):
          #   - "Capital One Shopping" ({aff8af88-06a9-4eee-b383-3af08c47b8c8})
          #     NUR only has a *different* Capital One extension ("Eno").
          #   - "Google Scholar Button" (button@scholar.google.com)
          #     NUR only has the unrelated "Semantic Scholar" extension.
          # These two would need manual installation (or a custom
          # buildFirefoxXpiAddon derivation) if migrating this profile.
        ];

      # Per-extension settings/storage (extensions.settings.<addonId>) and
      # permission enforcement. Not needed — none of the extensions above
      # require preseeded config.
      # extensions.force = false;
    };
  };
}
