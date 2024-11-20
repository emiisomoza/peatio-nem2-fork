RSpec.describe Peatio::Nem2::Wallet do
  let(:wallet) { Peatio::Nem2::Wallet.new }

  def request_headers(wallet)
    { 'Accept': 'application/json' }
  end

  let(:uri) { 'http://127.0.0.1:7890/' }

  let(:settings) do
    {
      wallet: { address: 'ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC',
                uri:     uri,
                secret: 'privateKey'
              },
      currency: { id: :erth,
                  base_factor: 1_000_000,
                  options: {} 
                }
    }
  end

  before { wallet.configure(settings) }

  private def get_response(path, file)
    getblock_response = JSON.parse( File.read( File.join("spec", "resources", path, file) ) )

    getblock_response.to_json
  end

  context :configure do
    let(:unconfigured_wallet) { Peatio::Nem2::Wallet.new }

    it 'requires wallet' do
      expect { unconfigured_wallet.configure(settings.except(:wallet)) }.to raise_error(Peatio::Wallet::MissingSettingError)

      expect { unconfigured_wallet.configure(settings) }.to_not raise_error
    end

    it 'requires currency' do
      expect { unconfigured_wallet.configure(settings.except(:currency)) }.to raise_error(Peatio::Wallet::MissingSettingError)

      expect { unconfigured_wallet.configure(settings) }.to_not raise_error
    end

    it 'sets settings attribute' do
      unconfigured_wallet.configure(settings)
      expect(unconfigured_wallet.settings).to eq(settings.slice(*Peatio::Nem2::Wallet::SUPPORTED_SETTINGS))
    end
  end

  context :create_address! do
    before(:all) { WebMock.disable_net_connect! }
    after(:all)  { WebMock.allow_net_connect! }

    before do
      stub_request( :get, uri + "account/generate" )
        .to_return( body: get_response("create_address", "new_address_ok.json") )
    end

    it 'Request creates new address successfully' do
      result = wallet.create_address!()
      expect(result.symbolize_keys).to eq(
        address: 'NCKMNCU3STBWBR7E3XD2LR7WSIXF5IVJIDBHBZQT',
        secret: '0962c6505d02123c40e858ff8ef21e2b7b5466be12c4770e3bf557aae828390f',
        details: { signer: 'c2e19751291d01140e62ece9ee3923120766c6302e1099b04014fe1009bc89d3' }
      )
    end
  end

  context :create_transaction! do
    before(:all) { WebMock.disable_net_connect! }
    after(:all)  { WebMock.allow_net_connect! }

    it 'requests rpc and sends erth with subtract fees and wallet with enough balance' do
      transaction = Peatio::Transaction.new(amount: 0.11, to_address: 'QRnrwkUBQ2E4ZJ3bj8jvn4Nwx4nJ2U7wXF', currency_id: 'erth', options: {message: "Memo"})
      stub_request( :post, uri + "transaction/prepare-announce" )
        .to_return( body: get_response('create_transaction','transaction_response_success.json') )
      stub_request(:get, uri + 'account/get')
        .with(:query => hash_including({"address" => 'something'}))
        .to_return( body: get_response('create_transaction','get_account_response.json') ) 
      stub_request(:get, "http://168.138.108.52:7890/namespace/mosaic/definition/page?namespace=rewards4earth")
        .to_return(status: 200, body: get_response('create_transaction','get_mosaic_definition_r4e.json'))  
      stub_request(:post, "http://168.138.108.52:7890/transaction/announce")
        .to_return(status: 200, body: get_response('create_transaction','anounce_response.json'))  
      stub_request(:get, 'http://168.138.108.52:7890/account/get?address=ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC')
        .to_return( body: get_response('create_transaction','get_account_with_enough_balance.json') ) 
      result = wallet.create_transaction!(transaction)
      puts("Result: ", result.inspect)
      expect(result.amount).to eq(0.11)
      expect(result.to_address).to eq('QRnrwkUBQ2E4ZJ3bj8jvn4Nwx4nJ2U7wXF')
      expect(result.hash).to eq('c1786437336da077cd572a27710c40c378610e8d33880bcb7bdb0a42e3d35586')
    end

    it 'requests rpc and sends erth with subtract fees and wallet without enough balance' do
      transaction = Peatio::Transaction.new(amount: 0.11, to_address: 'QRnrwkUBQ2E4ZJ3bj8jvn4Nwx4nJ2U7wXF', currency_id: 'erth', options: {})
      stub_request( :post, uri + "transaction/prepare-announce" )
        .to_return( body: get_response('create_transaction','transaction_response_success.json') )
      stub_request(:get, uri + 'account/get')
        .with(:query => hash_including({"address" => 'something'}))
        .to_return( body: get_response('create_transaction','get_account_response.json') ) 
      stub_request(:get, "http://168.138.108.52:7890/namespace/mosaic/definition/page?namespace=rewards4earth")
        .to_return(status: 200, body: get_response('create_transaction','get_mosaic_definition_r4e.json'))  
      stub_request(:post, "http://168.138.108.52:7890/transaction/announce")
        .to_return(status: 200, body: get_response('create_transaction','anounce_response.json'))  
      stub_request(:get, 'http://168.138.108.52:7890/account/get?address=ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC')
        .to_return( body: get_response('create_transaction','get_account_without_enough_balance.json') ) 
      result = wallet.create_transaction!(transaction)
      puts("Result: ", result.inspect)
      expect(result.amount).to eq(0.11)
      expect(result.to_address).to eq('QRnrwkUBQ2E4ZJ3bj8jvn4Nwx4nJ2U7wXF')
      expect(result.hash).to eq('c1786437336da077cd572a27710c40c378610e8d33880bcb7bdb0a42e3d35586')
    end

    it 'requests rpc and sends xem with subtract fees and wallet with enough balance' do
      transaction = Peatio::Transaction.new(amount: 1, to_address: 'QRnrwkUBQ2E4ZJ3bj8jvn4Nwx4nJ2U7wXF', currency_id: 'xem')
      stub_request( :post, uri + "transaction/prepare-announce" )
        .to_return( body: get_response('create_transaction','transaction_response_success.json') )
      stub_request(:get, uri + 'account/get')
        .with(:query => hash_including({"address" => 'something'}))
        .to_return( body: get_response('create_transaction','get_account_response.json') ) 
      stub_request(:get, "http://168.138.108.52:7890/namespace/mosaic/definition/page?namespace=rewards4earth")
        .to_return(status: 200, body: get_response('create_transaction','get_mosaic_definition_r4e.json'))  
      stub_request(:post, "http://168.138.108.52:7890/transaction/announce")
        .to_return(status: 200, body: get_response('create_transaction','anounce_response.json'))  
      stub_request(:get, 'http://168.138.108.52:7890/account/get?address=ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC')
        .to_return( body: get_response('create_transaction','get_account_with_enough_xem_balance.json') ) 
      result = wallet.create_transaction!(transaction)
      expect(result.amount).to eq(1)
      expect(result.to_address).to eq('QRnrwkUBQ2E4ZJ3bj8jvn4Nwx4nJ2U7wXF')
      expect(result.hash).to eq('c1786437336da077cd572a27710c40c378610e8d33880bcb7bdb0a42e3d35586')
    end

    it 'requests rpc and sends xem with subtract fees and wallet without enough balance' do
      transaction = Peatio::Transaction.new(amount: 1, to_address: 'QRnrwkUBQ2E4ZJ3bj8jvn4Nwx4nJ2U7wXF', currency_id: 'xem')
      stub_request( :post, uri + "transaction/prepare-announce" )
        .to_return( body: get_response('create_transaction','transaction_response_success.json') )
      stub_request(:get, uri + 'account/get')
        .with(:query => hash_including({"address" => 'something'}))
        .to_return( body: get_response('create_transaction','get_account_response.json') ) 
      stub_request(:get, "http://168.138.108.52:7890/namespace/mosaic/definition/page?namespace=rewards4earth")
        .to_return(status: 200, body: get_response('create_transaction','get_mosaic_definition_r4e.json'))  
      stub_request(:post, "http://168.138.108.52:7890/transaction/announce")
        .to_return(status: 200, body: get_response('create_transaction','anounce_response.json'))  
      stub_request(:get, 'http://168.138.108.52:7890/account/get?address=ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC')
        .to_return( body: get_response('create_transaction','get_account_without_enough_xem_balance.json') ) 
      result = wallet.create_transaction!(transaction)
      expect(result.amount).to eq(1)
      expect(result.to_address).to eq('QRnrwkUBQ2E4ZJ3bj8jvn4Nwx4nJ2U7wXF')
      expect(result.hash).to eq('c1786437336da077cd572a27710c40c378610e8d33880bcb7bdb0a42e3d35586')
    end
  end


  context :load_balance! do
    before(:all) { WebMock.disable_net_connect! }
    after(:all)  { WebMock.allow_net_connect! }

    before do
      stub_request(:get, '168.138.108.52:7890/account/mosaic/owned')
        .with(:query => hash_including({"address" => 'ND72SWJGHA7L7ECKIGWE5GLPSN5PYR6S3GZZOQBC'}))
        .to_return( body: get_response("load_balance_of_address", "balance_2.json") )
    end

    it 'Address with balance is defined' do
      result = wallet.load_balance!()
      expect(result).to be_a(BigDecimal)
      expect(result).to eq('2'.to_d)
    end
  end
  
end
