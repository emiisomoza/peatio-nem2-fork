RSpec.describe Peatio::Nem2::Client do
  let(:uri) { 'http://localhost:7890/' }
  before(:all) { WebMock.disable_net_connect! }
  after(:all) { WebMock.allow_net_connect! }

  subject { Peatio::Nem2::Client.new(uri) }

  context :initialize do
    it { expect{ subject }.not_to raise_error }
  end

  context :fetch_block_successfully do
    before do
      stub_request(:post, "#{uri}#{request_path}")
      .to_return(status: 200, body: response_body)
    end

    let(:response_body) {
      { example: "lalala" }.to_json
    }

    let(:request_path) { 'block/at/public' }

    it { expect{ subject.rest_api(:post, request_path) }.not_to raise_error }
    it { expect(subject.rest_api(:post, request_path)).to eq({"example"=>"lalala"}) }
  end

  context :invalid_address_request do
    before do
      stub_request(:get, uri)
      .with(body: {})
      .to_return(status: 400, body: response_body)
    end

    let(:response_body) {
      {
        "error": "string",
        "requestId": "string",
        "message": "message",
        "context": {
          "id": "9435643856345"
        },
        "name": "InvalidAddressId"
      }.to_json
    }

    it do
      expect{ subject.rest_api(:get, '') }.to \
              raise_error(Peatio::Nem2::Client::ConnectionError)
    end
  end

  context 'Request timeout' do
    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
    end

    it do
      expect{ subject.rest_api(:get, '/') }.to \
              raise_error(Peatio::Nem2::Client::ConnectionError)
    end
  end
end
