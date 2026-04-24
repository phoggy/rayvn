class ${projectNameClass} < Formula
  desc "${projectName} - ${projectDescription}"
  homepage "https://github.com/phoggy/${projectName}"
  url "{URL}"
  sha256 "{SHA256}"
  license "GPL-3.0-only"

{DEPENDS_ON}

  def install
    bin.install "bin/rayvn"
    bin.install "bin/rayvn.up"
    (share/"rayvn"/"lib").install Dir["lib/*.sh"]
    (share/"rayvn"/"templates").install Dir["templates/*"]
    (share/"rayvn"/"etc").install Dir["etc/*"]
    (share/"rayvn").install "rayvn.pkg"
  end

  test do
    system "#{bin}/rayvn", "--version"
  end
end
