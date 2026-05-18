{ pkgs, ... }: {
  channel = "stable-24.11";

  # Install system packages using clean global definitions
  packages = [
    pkgs.flutter
    pkgs.jdk17
  ];

  # Force the mobile simulator layout frame 
  idx.previews = {
    enable = true;
    previews = {
      android = {
        command = [ "flutter" "run" "--machine" "-d" "emulator-5554" ];
        manager = "flutter";
      };
    };
  };
}
