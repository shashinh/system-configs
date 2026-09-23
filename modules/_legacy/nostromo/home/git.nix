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
      # <hash> -<ref names> <subject> (<relative date>) <author>
      format.pretty = "format:%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset";
    };
  };
}
