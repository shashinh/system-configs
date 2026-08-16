{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Shashin Halalingaiah";
        email = "sshashinn@gmail.com";
      };
      # bare `git status` behaves as `git status -sb`
      status = {
        short = true;
        branch = true;
      };

      # bare `git log` defaults to a colorized one-line-per-commit format:
      # <hash> <subject> (<relative date>) <author>
      format.pretty = "format:%C(yellow)%h%C(reset) %s %C(green)(%cr)%C(reset) %C(blue)<%an>%C(reset)";
    };
  };
}
