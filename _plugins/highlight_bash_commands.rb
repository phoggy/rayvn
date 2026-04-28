# Post-process bash code blocks to wrap the first word of each line in <span class="nf">
# (Name.Function), giving command names a distinct color. Rouge's bash lexer leaves
# unrecognized command names as plain unstyled text, indistinguishable from their arguments.

Jekyll::Hooks.register [:pages, :documents], :post_render do |doc|
  next unless doc.output_ext == ".html"

  doc.output = doc.output.gsub(
    /(<div class="language-bash highlighter-rouge"[^>]*>.*?<pre class="highlight"><code>)(.*?)(<\/code><\/pre>)/m
  ) do
    prefix, inner, suffix = $1, $2, $3
    processed = inner.gsub(/^([^\S\n]*)([a-zA-Z_][a-zA-Z0-9_]*)/) do
      "#{$1}<span class=\"nf\">#{$2}</span>"
    end
    "#{prefix}#{processed}#{suffix}"
  end
end
