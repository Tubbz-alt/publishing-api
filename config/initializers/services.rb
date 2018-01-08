module PublishingAPI
  # To be set in dev mode so that this can run when the draft content store isn't running.
  cattr_accessor :swallow_connection_errors

  def self.register_service(name:, client:)
    @services ||= {}

    @services[name] = client
  end

  def self.service(name)
    @services[name] || raise(ServiceNotRegisteredException.new(name))
  end

  class ServiceNotRegisteredException < Exception; end
end

PublishingAPI.register_service(
  name: :draft_content_store,
  client: ContentStoreWriter.new(Plek.find('draft-content-store'))
)

PublishingAPI.register_service(
  name: :live_content_store,
  client: ContentStoreWriter.new(Plek.find('content-store'))
)

if ENV['DISABLE_QUEUE_PUBLISHER'] || (Rails.env.test? && ENV['ENABLE_QUEUE_IN_TEST_MODE'].blank?)
  rabbitmq_config = { noop: true }
elsif ENV["RABBITMQ_URL"] && ENV["RABBITMQ_EXCHANGE"]
  rabbitmq_config = { exchange: ENV["RABBITMQ_EXCHANGE"] }
else
  rabbitmq_config = Rails.application.config_for(:rabbitmq).symbolize_keys
end

PublishingAPI.register_service(
  name: :queue_publisher,
  client: QueuePublisher.new(rabbitmq_config)
)

if Rails.env.development?
  PublishingAPI.swallow_connection_errors = true
end
