RSpec.describe Peatio::Nem2::Blockchain do
  context :features do
    it 'defaults' do
      blockchain1 = Peatio::Nem2::Blockchain.new
      expect(blockchain1.features).to eq Peatio::Nem2::Blockchain::DEFAULT_FEATURES
    end

    it 'override defaults' do
      blockchain2 = Peatio::Nem2::Blockchain.new(cash_addr_format: true)
      expect(blockchain2.features[:cash_addr_format]).to be_truthy
    end

    it 'custom feautures' do
      blockchain3 = Peatio::Nem2::Blockchain.new(custom_feature: :custom)
      expect(blockchain3.features.keys).to contain_exactly(*Peatio::Nem2::Blockchain::SUPPORTED_FEATURES)
    end
  end

  context :configure do
    let(:blockchain) { Peatio::Nem2::Blockchain.new }
    it 'default settings' do
      expect(blockchain.settings).to eq({})
    end

    it 'currencies and server configuration' do
      currencies = [{ id: :ltc,
                      base_factor: 1_000_000,
                      options: {} }]
      settings = { server: 'http://localhost:7890/',
                   currencies: currencies,
                   something: :custom }
      blockchain.configure(settings)
      expect(blockchain.settings).to eq(settings.slice(*Peatio::Blockchain::Abstract::SUPPORTED_SETTINGS))
    end
  end

  context :latest_block_number do
    before(:all) { WebMock.disable_net_connect! :allow_localhost => true }
    after(:all)  { WebMock.allow_net_connect! }

    let(:server) { 'http://localhost:7890/' }

    let(:response) do
      response_file
        .yield_self { |file_path| File.open(file_path) }
        .yield_self { |file| JSON.load(file) }
    end

    let(:response_error) do
      response_error_file
        .yield_self { |file_path| File.open(file_path) }
        .yield_self { |file| JSON.load(file) }
    end

    let(:response_file) do
      File.join('spec', 'resources', 'last_block', '123456.json')
    end

    let(:response_error_file) do
      File.join('spec', 'resources', 'methodnotfound', 'error.json' )
    end

    let(:blockchain) do
      Peatio::Nem2::Blockchain.new.tap {|b| b.configure(server: server)}
    end

    it 'returns latest block number' do
      stub_request(:get, server + 'chain/height')
        .to_return(body: response.to_json)
      expect(blockchain.latest_block_number).to eq(3664929)
    end

    it 'raises error if there is error in response body' do
      stub_request(:get, server + 'chain/height')
        .to_return(body:  response_error.to_json)
      expect{ blockchain.latest_block_number }.to raise_error(Peatio::Nem2::Client::ConnectionError)
    end
  end

  context :fetch_block! do
    before(:all) { WebMock.disable_net_connect! }
    after(:all)  { WebMock.allow_net_connect! }

    let(:server) { "http://127.0.0.1:7890/" }

    let(:currency) do
      { id: :erth,
        base_factor: 1_000_000,
        options: {} }
    end

    let(:blockchain) do
      Peatio::Nem2::Blockchain.new.tap { |b| b.configure(server: server, currencies: [currency]) }
    end

    it "Builds expected number of trully transactions" do
      stub_request(:post, server + 'block/at/public')
        .with(body: { "height": 10205 }.to_json)
        .to_return( body: get_response("get_block", "10205.json") )
      stub_request(:get, "http://127.0.0.1:7890/account/transfers/all?address=NALICELGU3IVY4DPJKHYLSSVYFFWYS5QPLYEZDJJ") 
        .to_return( body: get_response("get_block", "all_transfers_DJJ.json") )
      expect(blockchain.fetch_block!(10205).count).to eq(2)
      expect(blockchain.fetch_block!(10205).all?(&:valid?)).to be_truthy
    end

    it "Builds expected number of trully mosaics transaction" do
      stub_request(:post, server + 'block/at/public')
        .with(body: { "height": 3783753 }.to_json)
        .to_return( body: get_response("get_block", "3783753_mosaic.json") )
      stub_request(:get, "http://127.0.0.1:7890/account/transfers/all?address=NCKQ4BSRF5VPCR3TQUK7DHO2G24H4G45PWOAR5NB") 
        .to_return( body: get_response("get_block", "all_transfers_DJJ.json") )  
      expect(blockchain.fetch_block!(3783753).count).to eq(2)
      expect(blockchain.fetch_block!(3783753).all?(&:valid?)).to be_truthy
    end

    it "Builds a block with no transactions" do
      stub_request(:post, server + 'block/at/public')
        .with(body: { "height": 10210 }.to_json)
        .to_return( body: get_response("get_block", "10210.json") )  

      expect(blockchain.fetch_block!(10210).count).to eq(0)
      expect(blockchain.fetch_block!(10210)).to be_a_kind_of(Peatio::Block)
    end

    it "Builds expected number of trully mosaics transaction except from fee wallet" do
      stub_request(:post, server + 'block/at/public')
        .with(body: { "height": 3783753 }.to_json)
        .to_return( body: get_response("get_block", "block_with_fee_wallet_transaction.json") )
      stub_request(:get, "http://127.0.0.1:7890/account/transfers/all?address=NCKQ4BSRF5VPCR3TQUK7DHO2G24H4G45PWOAR5NB") 
        .to_return( body: get_response("get_block", "all_transfers_DJJ.json") )  
      expect(blockchain.fetch_block!(3783753).count).to eq(1)
      expect(blockchain.fetch_block!(3783753).all?(&:valid?)).to be_truthy
    end

  end

  private def get_response(path, file)
    getblock_response = JSON.parse( File.read( File.join("spec", "resources", path, file) ) )

    getblock_response.to_json
  end


  context :load_balance_of_address! do
    before(:all) { WebMock.disable_net_connect! }
    after(:all)  { WebMock.allow_net_connect! }

    let(:server) { "http://127.0.0.1:7890/" }

    let(:currency1) do
      { id: 'erth',
        base_factor: 1_000_000,
        options: {} }
    end

    let(:currency2) do
      { id: 'xem',
        base_factor: 1_000_000,
        options: {} }
    end

    let(:blockchain) do
      Peatio::Nem2::Blockchain.new.tap { |b| b.configure(server: server, currencies: [currency1, currency2]) }
    end

    context 'Address with balance is defined' do
      before do
        stub_request(:get, '168.138.108.52:7890/account/mosaic/owned')
          .with(:query => hash_including({"address" => 'ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC'}))
          .to_return( body: get_response("load_balance_of_address", "balance_2.json") )
        stub_request(:get, '168.138.108.52:7890/account/get')
          .with(:query => hash_including({"address" => 'ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC'}))
          .to_return( body: get_response("load_balance_of_address", "xem_balance_10.json") )
        stub_request(:get, '168.138.108.52:7890/account/mosaic/owned')
          .with(:query => hash_including({"address" => 'NC64UFOWRO6AVMWFV2BFX2NT6W2GURK2EOX6FFMZ'}))
          .to_return( body: get_response("load_balance_of_address", "balance_0.json") )
      end 

      it 'Requests load_balance_of_address and finds address balance for erth' do
        address = 'ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC'

        result = blockchain.load_balance_of_address!(address, :erth)
        expect(result).to be_a(BigDecimal)
        expect(result).to eq('2'.to_d)
      end

      it 'Requests load_balance_of_address and finds address balance for xem' do
        address = 'ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC'

        result = blockchain.load_balance_of_address!(address, :xem)
        expect(result).to be_a(BigDecimal)
        expect(result).to eq('10'.to_d)
      end

      it 'Requests load_balance_of_address and finds address with zero balance' do
        address = 'NC64UFOWRO6AVMWFV2BFX2NT6W2GURK2EOX6FFMZ'

        result = blockchain.load_balance_of_address!(address, :erth)
        expect(result).to be_a(BigDecimal)
        expect(result).to eq('0'.to_d)
      end
    end

    context 'Address is not defined' do
      before do
        stub_request(:get, '168.138.108.52:7890/account/mosaic/owned')
          .with(:query => hash_including({"address" => 'NAEAUINFUENY3YHWQARJVE4OFLPK5UCRV6DASFAP'}))
          .to_return( body: {}.to_json )
      end 

      it 'Requests load_balance_of_address and do not find address' do
        address = 'NAEAUINFUENY3YHWQARJVE4OFLPK5UCRV6DASFAP'
        expect{ blockchain.load_balance_of_address!(address, :erth)}.to raise_error(Peatio::Blockchain::UnavailableAddressBalanceError)
      end
    end

    context 'Client error is raised' do
      before do
        stub_request(:get, '168.138.108.52:7890/account/mosaic/owned')
          .with(:query => hash_including({"address" => 'anything'}))
          .to_return(body: { result: nil,
                             error:  { code: -32601, message: 'Method not found' },
                             id:     nil }.to_json)
      end

      it 'Raise wrapped client error' do
        expect{ blockchain.load_balance_of_address!('anything', :erth)}.to raise_error(Peatio::Blockchain::UnavailableAddressBalanceError)
      end
    end

  end

end
