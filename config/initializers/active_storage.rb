# Ensure Active Storage has a variant processor and image-processing backend loaded.
# This helps avoid "undefined method `new' for nil" when ActiveStorage can't find
# a transformer implementation at runtime.
if defined?(ActiveStorage)
  begin
    require "image_processing/mini_magick"
  rescue LoadError
    Rails.logger.warn("image_processing/mini_magick not available; add mini_magick or ruby-vips to your Gemfile and run `bundle install`")
  end

  # Ensure a variant processor is configured. Prefer an explicit application config
  # value but fall back to :mini_magick when unset.
  processor = (Rails.application.config.active_storage.variant_processor rescue nil) || :mini_magick
  Rails.application.config.active_storage.variant_processor = processor

  # Ensure ActiveStorage has a registered transformer for the selected processor.
  if defined?(ActiveStorage::Transformers)
    begin
      registry = ActiveStorage::Transformers.respond_to?(:registry) ? ActiveStorage::Transformers.registry : nil
      if registry.nil? || registry[processor].nil?
        require "active_storage/transformers/image_processing_transformer"
        ActiveStorage::Transformers.register(processor, ActiveStorage::Transformers::ImageProcessingTransformer)
      end
    rescue LoadError, NameError => e
      Rails.logger.warn("Active Storage transformer registration failed: ".concat(e.message))
    end
  end
end
