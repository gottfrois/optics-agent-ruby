module OpticsAgent
  class Railtie < Rails::Railtie
    initializer "optics_agent_logger_initialization" do
      OpticsAgent::Agent.logger = Rails.logger
    end
  end
end
