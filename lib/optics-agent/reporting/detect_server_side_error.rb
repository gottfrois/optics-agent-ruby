require 'faraday'
require 'set'

module OpticsAgent
  module Reporting
    class DetectServerSideError < Faraday::Middleware
      RETRY_ON = Set.new [500, 502, 503, 504]

      def call(env)
        @app.call(env).on_complete do |r|
          if RETRY_ON.include? env[:status]
            raise "#{r[:status]} status code"
          end
        end
      end
    end
  end
end
