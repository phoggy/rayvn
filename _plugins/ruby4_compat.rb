# Restore tainted? for Ruby 3.2+ compatibility with Liquid 4.x (removed from Ruby 3.2).
[String, Integer, Float, Array, Hash, Symbol, NilClass, TrueClass, FalseClass].each do |klass|
  klass.define_method(:tainted?) { false }
end

# Patch jekyll-sass-converter 3.x to support silence_deprecations from _config.yml sass section.
# The converter passes quiet_deps and verbose to sass-embedded but not silence_deprecations.
Jekyll::Hooks.register :site, :after_init do |site|
  require "jekyll/converters/scss"
  Jekyll::Converters::Scss.prepend(Module.new do
    def sass_configs
      configs = super
      silence = jekyll_sass_configuration["silence_deprecations"]
      configs[:silence_deprecations] = Array(silence).map(&:to_sym) if silence
      configs
    end
  end)
end
