class ${projectNameClass} < Formula
  desc "${projectName} - ${projectDescription}"
  homepage "https://github.com/phoggy/${projectName}"
  url "{URL}"
  sha256 "{SHA256}"
  license "GPL-3.0-only"

{DEPENDS_ON}

  def install
    bin.install "bin/${projectName}"
    (share/"${projectName}"/"lib").install Dir["lib/*.sh"]
    (share/"${projectName}").install "rayvn.pkg"
  end

  test do
    system "#{bin}/${projectName}", "--version"
  end
end
