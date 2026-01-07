require "html"
require "markd"

module Blog
  module ViewHelpers
    def format_time(time : Time?) : String
      return "" if time.nil?
      time.to_s("%B %d, %Y")
    end

    def format_datetime(time : Time?) : String
      return "" if time.nil?
      time.to_s("%B %d, %Y at %I:%M %p")
    end

    def h(text : String?) : String
      return "" if text.nil?
      HTML.escape(text)
    end

    def truncate(text : String?, length : Int32 = 150) : String
      return "" if text.nil?
      if text.size > length
        text[0, length] + "..."
      else
        text
      end
    end

    def markdown(text : String?) : String
      return "" if text.nil?
      Markd.to_html(text)
    end

    def simple_format(text : String?) : String
      return "" if text.nil?
      paragraphs = text.split(/\n\n+/)
      paragraphs.map { |p| "<p>#{HTML.escape(p).gsub("\n", "<br>")}</p>" }.join("\n")
    end

    def pluralize(count : Int32, singular : String, plural : String? = nil) : String
      plural ||= singular + "s"
      count == 1 ? "#{count} #{singular}" : "#{count} #{plural}"
    end
  end
end
