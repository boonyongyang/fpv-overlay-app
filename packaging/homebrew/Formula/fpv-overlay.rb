class FpvOverlay < Formula
  desc "Command-line FPV telemetry overlay renderer"
  homepage "https://github.com/boonyongyang/fpv-overlay-app"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/boonyongyang/fpv-overlay-app/releases/download/__RELEASE_TAG__/fpv-overlay-cli-macos-arm64-__VERSION__.tar.gz"
      sha256 "__ARM64_SHA256__"
    else
      url "https://github.com/boonyongyang/fpv-overlay-app/releases/download/__RELEASE_TAG__/fpv-overlay-cli-macos-x64-__VERSION__.tar.gz"
      sha256 "__X64_SHA256__"
    end
  end

  def install
    libexec.install "bin", "runtime"

    (bin/"fpv-overlay").write_env_script(
      libexec/"bin/fpv-overlay",
      FPV_OVERLAY_RUNTIME_DIR: "#{libexec}/runtime",
    )
  end

  test do
    assert_match "fpv-overlay", shell_output("#{bin}/fpv-overlay --version")
  end
end
