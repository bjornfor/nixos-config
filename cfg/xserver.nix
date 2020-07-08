{
  services.xserver = {
    enable = true;
    libinput.enable = true;
    libinput.additionalOptions = ''
      # Reduce sensitiviy of Wacom BambooFun 6x8 Pad
      # * 4-point bezier curve: "x0/y0 x1/y1 x2/y2 x3/y3"
      # * default value: "0/0 0/0 1/1 1/1"
      # A bit too hard: "0.5/0 0.5/0 1/1 1/1"
      Option "TabletToolPressureCurve" "0.3/0 0.3/0 1/1 1/1"
    '';
  };
}
