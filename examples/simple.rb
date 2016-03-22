require "breaker"

circuit = ::Breaker::Circuit.get_or_register("https://example.com")

result = circuit.execute(:execution_timeout_in_milliseconds => 10_000) do
  client = HTTPClient.new(:base_url => "https://example.com")
  client.get("test")
end

# Re-raise error if one was present
raise result.error if result.error

::API::Response.new(result.value)
