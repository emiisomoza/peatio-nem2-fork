require 'date'
require 'nem'

module Peatio
  module Nem2
    class Wallet < Peatio::Wallet::Abstract

      TIME_DIFFERENCE_IN_MINUTES = 10
      XLM_MEMO_TYPES = { 'memoId': 'id', 'memoText': 'text', 'memoHash': 'hash', 'memoReturn': 'return' }
    ###  

      DEFAULT_FEATURES = { skip_deposit_collection: false }.freeze
      DEFAULT_DEADLINE = 3600 # 1 hour
      DEFAULT_FEE = 0.05

      def initialize(custom_features = {})
        @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
        @settings = {}
      end

      def configure(settings = {})
        # Clean client state during configure.
        @client = nil

        @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))

        @wallet = @settings.fetch(:wallet) do
          raise Peatio::Wallet::MissingSettingError, :wallet
        end.slice(:uri, :address, :secret, :details)

        @currency = @settings.fetch(:currency) do
          raise Peatio::Wallet::MissingSettingError, :currency
        end.slice(:id, :base_factor, :options)

        Nem.configure do |conf|
          # set :mainnet if you'd like to use on mainnet(default :testnet)
          conf.default_network = :mainnet
        end
      end

      private def client
        uri = @wallet.fetch(:uri) { raise Peatio::Wallet::MissingSettingError, :uri }
        @client ||= Client.new(uri)
      end


      def create_address!(_options = {})
      response = client.rest_api( :get, "account/generate" )
      {
        address: response.fetch('address'),
        secret: response.fetch('privateKey'),
        details: { signer: response.fetch('publicKey') }
      }
      rescue Nem2::Client::Error => e
        raise Peatio::Wallet::ClientError, e
      end
      

      def load_balance!
        quantity = 0
        address = @wallet.fetch(:address).to_s

        # New Node
        node = Nem::Node.new(host: '168.138.108.52')
        # New Account Endpoint Object
        account_endpoint = Nem::Endpoint::Account.new(node)
        
        begin
          if(@currency.fetch(:id).to_s == 'xem')
            # fetch owned XEMs of account
            response = account_endpoint.find(address)
            quantity = (response.balance.to_d / 1_000_000).to_d
          else  
            # fetch owned mosaics of account
            response = account_endpoint.mosaic_owned(address)
            
            # find the collection of mosaics that have the namespace
            r4eMosaicCollection = response.find_by_namespace_id('rewards4earth')

            # find the mosaic attachment with the namespace + name of the mosaic   
            mosaicAttachment = r4eMosaicCollection.find_by_fqn('rewards4earth:' + 'erth')

            quantity = (mosaicAttachment&.quantity / 1_000_000).to_d
          end  
        rescue Client::Error => e
          raise Peatio::Blockchain::ClientError, e
        end
        quantity

      rescue Client::Error => e
        raise Peatio::Wallet::ClientError, e
      end


      def create_transaction!(transaction, options = {})
        node = Nem::Node.new(host: '168.138.108.52')
        if(transaction.currency_id == 'erth')
          check_balance_and_send_fee_funds(transaction, node, DEFAULT_FEE)
          result = send_erth(transaction, node)
        else
          check_balance_and_send_fee_funds(transaction, node, transaction.amount.to_d + DEFAULT_FEE)
          result = send_xem(transaction, node)  
        end

        if result.message.upcase == "SUCCESS"                    
          transaction.hash = result.transaction_hash
          transaction
        end  
      rescue Nem2::Client::Error => e
        raise Peatio::Wallet::ClientError, e
      end

      private def send_xem(transaction, node)
        kp = Nem::Keypair.new(@settings[:wallet][:secret])
        tx_endpoint = Nem::Endpoint::Transaction.new(node)
        
        tx = Nem::Transaction::Transfer.new(
          transaction.to_address, 
          transaction.amount.to_d
        )
        
        begin
          req = Nem::Request::Announce.new(tx, kp)
          res = tx_endpoint.announce(req)
        rescue => error
          puts("XEM error: "+ error.message)
        end

        res   

      end

      private def send_erth(transaction, node)
        puts("Transaction: "+ transaction.inspect)
        kp = Nem::Keypair.new(@settings[:wallet][:secret])
        tx_endpoint = Nem::Endpoint::Transaction.new(node)
        
        if( transaction.options != nil && transaction.options[:message] != nil )
          tx_message = transaction.options[:message]
          tx = Nem::Transaction::Transfer.new(
            transaction.to_address, 
            1,
            tx_message.to_s
          )
        else
          tx = Nem::Transaction::Transfer.new(
            transaction.to_address, 
            1
          )
        end 

        # fetch mosaic definition
        ns_endpoint = Nem::Endpoint::Namespace.new(node)
        mo_def = ns_endpoint.mosaic_definition('rewards4earth').first
        moa = Nem::Model::MosaicAttachment.new(
          mosaic_id: mo_def.id,
          properties: mo_def.properties,
          quantity: transaction.amount.to_d
        )

        tx.mosaics << moa
        
        req = Nem::Request::Announce.new(tx, kp)
        res = tx_endpoint.announce(req)

        res
      end

      private def check_balance_and_send_fee_funds(transaction, node, min_amount)
        quantity = 0
        address = @wallet.fetch(:address).to_s

        # New Account Endpoint Object
        account_endpoint = Nem::Endpoint::Account.new(node)

        # fetch owned XEMs of account
        response = account_endpoint.find(address)
        balance = response.balance

        if balance.to_d < min_amount.to_d * 1_000_000
          #kp fee wallet to send 1 XEM to the sender account as transaction fee
          kp = Nem::Keypair.new('6e1c0313290a64496ef988a5a6cb442da85f1961408cb9b627e261f25bb95d48')

          tx_endpoint = Nem::Endpoint::Transaction.new(node)
          
          tx = Nem::Transaction::Transfer.new(
            address, 
            1
          )
          
          begin
            req = Nem::Request::Announce.new(tx, kp)
            res = tx_endpoint.announce(req)
            sleep(1)
          rescue => error
            puts("XEM error: "+ error.message)
          end   
        end  
      end  

    end
  end
end
