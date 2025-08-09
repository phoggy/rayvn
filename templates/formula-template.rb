class ${projectNameInitialCap} < Formula
  desc "A placeholder for the '${projectName}' rayvn project."
  homepage "${repoUrl}"
  version "0.0.0"
  license "GPL-3.0"

  def install
    # Just a placeholder for now, does not install anything
  end

  def caveats
    <<~EOS
      🚧 UNDER CONSTRUCTION 🚧

      Project '${projectName}' is currently being developed, check back soon for updates.
      
      For more information, visit: #{homepage}
    EOS
  end
end
