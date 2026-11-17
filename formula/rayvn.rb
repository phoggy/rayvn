class ${projectNameClass} < Formula
  desc "${projectDescription}"
  homepage "https://github.com/phoggy/${projectName}"
  url "{URL}"
  sha256 "{SHA256}"
  license "GPL-3.0-only"

{DEPENDS_ON}

  def install
    bin.install "bin/rayvn"
    bin.install "bin/rayvn.up"
    bin.install "bin/rayvn-bash" # the interpreter of rayvn scripts' #!/usr/bin/env rayvn-bash shebang
    bin.install "bin/rayvn-tmp"
    (share/"rayvn"/"lib").install Dir["lib/*.sh"]
    (share/"rayvn"/"templates").install Dir["templates/*"]
    (share/"rayvn"/"etc").install Dir["etc/*"]
    (share/"rayvn").install "rayvn.pkg"
    bash_completion.install "completions/rayvn.bash" => "rayvn"
    zsh_completion.install "completions/rayvn.zsh" => "_rayvn"
  end

  test do
    system "#{bin}/rayvn", "--version"
  end
end
