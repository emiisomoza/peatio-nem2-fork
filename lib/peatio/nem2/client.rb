require 'faraday'
require 'better-faraday'
require 'memoist'

module Peatio
  module Nem2
    class Client
      Error = Class.new(StandardError)
      ConnectionError = Class.new(Error)

      class ResponseError < Error
        def initialize(code, msg)
          @code = code
          @msg = msg
        end

        def message
          "#{@msg} (#{@code})"
        end
      end

      extend Memoist

      def initialize(endpoint)
        @json_rpc_endpoint = URI.parse(endpoint)
      end

      def rest_api(verb, path, data = nil)
        args = [@json_rpc_endpoint.to_s + path]

        if data
          if %i[post put patch].include?(verb)
            args << data.compact.to_json
            args << { 'Content-Type' => 'application/json' }
          else
            args << data.compact
            args << {}
          end
        else
          args << nil
          args << {}
        end
        response = Faraday.send(verb, *args)
        response.assert_success!
        response = JSON.parse(response.body)
        response['error'].tap do |error|
          raise ResponseError.new(response['status'], response['error']) if error
        end
        response
      rescue Faraday::Error => e
        if e.is_a?(Faraday::ConnectionFailed) || e.is_a?(Faraday::TimeoutError)
          raise ConnectionError, e
        else
          raise ConnectionError, JSON.parse(e.response.body)['message']
        end
      end

    end
  end
end
