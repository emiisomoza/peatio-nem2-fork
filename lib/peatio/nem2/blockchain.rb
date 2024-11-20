require 'nem'

module Peatio
  module Nem2
    # TODO: Processing of unconfirmed transactions from mempool isn't supported now.
    class Blockchain < Peatio::Blockchain::Abstract

      DEFAULT_FEATURES = {case_sensitive: true, cash_addr_format: false}.freeze

      def initialize(custom_features = {})
        @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
        @settings = {}
      end

      def configure(settings = {})
        # Clean client state during configure.
        @client = nil
        @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))

        Nem.configure do |conf|
          # set :mainnet if you'd like to use on mainnet(default :testnet)
          conf.default_network = :mainnet
        end
      end

      def latest_block_number
        response = client.rest_api(:get, "chain/height")
        response.fetch('height')
      rescue Client::Error => e
        raise Peatio::Nem2::Client::ConnectionError, e
      end

      def client
        @client ||= Client.new(settings_fetch(:server))
      end

      def settings_fetch(key)
        @settings.fetch(key) { raise Peatio::Blockchain::MissingSettingError, key.to_s }
      end

      def fetch_block!(block_number)
  
        txs = []
        block = nil

        puts("Block number: " + block_number.to_s)

        # new node
        node = Nem::Node.new(host: '168.138.108.52')
        # new Account Endpoint Object
        account_endpoint = Nem::Endpoint::Account.new(node)
        
        blockResponse = client.rest_api(:post, "block/at/public", {
          height: block_number
        }.compact)

        puts("Block response: " + blockResponse.inspect)

        if blockResponse['transactions'].present?
          blockResponse['transactions'].each_with_index do |tx, i|
          
            #Filter transactions from fee wallet
          if !tx['recipient'].blank? and tx['signer'] != '8274c7c04df45f71b2e243db238f52670a46d2caf539ea6375fda68f75bd07f5' 
            puts("Recipient: " + tx['recipient']&.to_s)  
            transactionsResponse = client.rest_api(:get, "account/transfers/all?address=" + tx['recipient']&.to_s)  

            data = transactionsResponse&.fetch('data')

            #address_transactions = account_endpoint.transfers_all(tx['recipient'])

            puts("Response data: " + data&.inspect)
            puts("Signature: " + tx['signature'])

            #transaction data.detect{|i| i.transaction.signature == tx['signature']}
            transaction = data&.find { |n| puts n.inspect; n&.fetch('transaction')&.fetch('signature') == tx['signature'] }

            puts("Filtered transaction: " + transaction.inspect)

            transaction_hash = transaction&.fetch('meta')&.fetch('hash')&.fetch('data')
            if !transaction_hash.nil?
              puts("Transaction hash: " + transaction_hash.inspect)
            end  

            currency_tx = {
              hash: transaction_hash.nil? ? tx['signature'] : transaction_hash,
              txout: i,
              to_address: tx['recipient'],
              status: 'success',
              block_number: block_number, 
            }  

            if tx['mosaics'].present?
              currency_tx.merge!( amount: tx['mosaics'].first['quantity'].to_d / 1_000_000.to_d )
              currency_tx.merge!( currency_id: 'erth' )
            else
              currency_tx.merge!( amount: tx['amount'].to_d / 1_000_000.to_d )
              currency_tx.merge!( currency_id: 'xem' )
            end  

            txs << Peatio::Transaction.new( currency_tx )      

            end
          end  
        end

        block = Peatio::Block.new(block_number, txs)
        puts("Block: " + block.inspect)
        block
      end

      def load_balance_of_address!(address, currency_id)
        quantity = 0
        puts("load_balance_of_address")
        puts("Address: " + address.to_s)
        puts("currency_id: " + currency_id.to_s)
        currency = settings[:currencies].find { |c| c[:id] == currency_id.to_s }
        puts("Currency: " + currency.to_s)

        # New Node
        node = Nem::Node.new(host: '168.138.108.52')
        # New Account Endpoint Object
        account_endpoint = Nem::Endpoint::Account.new(node)
        
        begin
          if(currency_id.to_s.downcase == 'xem')
            # fetch owned XEMs of account
            response = account_endpoint.find(address).balance
            puts( "XEMs address balance: " + response.to_s )
            quantity = convert_from_base_unit(response.to_d, currency)
          else  
            # fetch owned mosaics of account
            response = account_endpoint.mosaic_owned(address)
            puts("Mosaics: " + response.to_s)
            
            # find the collection of mosaics that have the namespace
            r4eMosaicCollection = response.find_by_namespace_id('rewards4earth')
            puts("r4eMosaic: " + r4eMosaicCollection.to_s)

            # find the mosaic attachment with the namespace + name of the mosaic   
            mosaicAttachment = r4eMosaicCollection.find_by_fqn('rewards4earth:' + 'erth')

            puts("mosaicAttachment: " + mosaicAttachment.to_s)
            puts("mosaicAttachmentQuantity: " + mosaicAttachment&.quantity.to_s)
            quantity = convert_from_base_unit(mosaicAttachment&.quantity, currency)
          end  
        rescue => error
          puts("error: " + error.to_s)
          raise Peatio::Blockchain::UnavailableAddressBalanceError, address
        end

        quantity.to_d

      rescue Client::Error => e
        raise Peatio::Blockchain::ClientError, e
      end

      private def convert_from_base_unit(value, currency)
        puts( "base_factor: " + currency.fetch(:base_factor).to_s )
        value.to_d / currency.fetch(:base_factor).to_d
      end

    end
  end
end
