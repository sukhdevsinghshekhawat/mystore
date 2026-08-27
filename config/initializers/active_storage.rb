# Ensure the ActiveStorage variant processor's native image library is available
# and turn the cryptic runtime failure into an actionable message.
#
# Background
# ----------
# Rails 8.1 defaults `config.active_storage.variant_processor` to `:vips`.
# `:vips` needs the system libvips library, `:mini_magick` needs ImageMagick.
# When the required library is missing, the ActiveStorage engine only logs a
# warning and leaves `ActiveStorage.variant_transformer` nil, so the first
# image-variant request crashes with a cryptic:
#
#   NoMethodError (undefined method `new' for nil)
#     activestorage/app/models/active_storage/variation.rb:85:in `transformer'
#
# We intentionally do NOT stop boot here (the rest of the app keeps working);
# we log a clear warning and make the variant request raise a useful error
# instead of the NoMethodError above.
if defined?(ActiveStorage)
  processor = (Rails.application.config.active_storage.variant_processor rescue nil)&.to_sym || :mini_magick
  Rails.application.config.active_storage.variant_processor = processor

  unless processor.in?(%i[vips mini_magick disabled])
    raise ArgumentError,
          "Unknown config.active_storage.variant_processor #{processor.inspect}. " \
          "Supported values: :vips, :mini_magick, :disabled."
  end

  if processor != :disabled
    require_path = processor == :vips ? "image_processing/vips" : "image_processing/mini_magick"
    available =
      begin
        require require_path
        if processor == :mini_magick
          path_dirs = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
          %w[magick mogrify convert].any? { |bin| path_dirs.any? { |dir| File.executable?(File.join(dir, bin)) } }
        else
          true
        end
      rescue LoadError
        false
      end

    unless available
      help = <<~ERROR.squish
        ActiveStorage variant_processor is set to :#{processor} but its native image
        library is not installed.
        - For :vips, install libvips:        brew install vips
        - For :mini_magick, install ImageMagick: brew install imagemagick
        - To switch processor, e.g. in config/environments/*.rb or an initializer:
          config.active_storage.variant_processor = #{(processor == :vips) ? :mini_magick : :vips}
        - To disable image variants entirely:
          config.active_storage.variant_processor = :disabled
      ERROR

      Rails.logger.warn("[active_storage] " + help)

      # ActiveStorage would leave `variant_transformer` nil here (the engine
      # only logs a warning and skips the assignment), which triggers
      # `NoMethodError (undefined method `new' for nil)` on the first variant
      # request. Install a fallback transformer that raises the clear message
      # instead.
      ActiveStorage.variant_transformer = Class.new do
        define_method(:initialize) do |*_|
          raise RuntimeError, help
        end
      end
    end
  end
end
