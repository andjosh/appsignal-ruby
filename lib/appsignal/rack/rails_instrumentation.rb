require 'rack'

module Appsignal
  module Rack
    class RailsInstrumentation
      def initialize(app, options = {})
        Appsignal.logger.debug 'Initializing Appsignal::Rack::RailsInstrumentation'
        @app, @options = app, options
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          @app.call(env)
        end
      end

      def call_with_appsignal_monitoring(env)
        request = ActionDispatch::Request.new(env)
        transaction = Appsignal::Transaction.create(
          env['action_dispatch.request_id'],
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          :params_method => :filtered_parameters
        )
        begin
          @app.call(env)
        rescue => error
          transaction.set_error(error)
          raise error
        ensure
          controller = env['action_controller.instance']
          if controller
            transaction.set_action("#{controller.class.to_s}##{controller.action_name}")
          end
          transaction.set_http_or_background_queue_start
          transaction.set_metadata('path', request.path)
          transaction.set_metadata('method', request.request_method)
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
